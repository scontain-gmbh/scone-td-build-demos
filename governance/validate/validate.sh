#!/usr/bin/env bash
# Runs the governance demo end to end against a local stand-in for the policy-signing
# service (validate/mock_governance.py), in two cases:
#
#   APPROVED  the stand-in approves and REALLY signs every submitted session
#             (`scone session sign`), so the SignedPolicy resources are valid, the CAS
#             accepts them and the confidential workload attests and receives its secret.
#   REJECTED  a signer refuses (ABORTED): `scone-td-build apply` fails and nothing is
#             produced, so nothing can be deployed.
#
# What is simulated is the *service* (one key, automatic approval) rather than the real
# multi-signer workflow. The image, the signatures, the CAS and the attestation are real.
#
# Requirements: docker, python3, `scone` (the stand-in signs with it), and a
# scone-td-build with governance support (SCONE_TD_BUILD=<path>, or on PATH).
# With DEPLOY=1 it also needs a cluster whose CAS matches ${CAS_NAME}.${CAS_NAMESPACE}.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the governance/ demo dir
cd "$HERE"

BIN="${SCONE_TD_BUILD:-scone-td-build}"
PORT="${MOCK_PORT:-8899}"
TAG="ttl.sh/governance-demo-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

# shellcheck disable=SC1090
[ -f "$HOME/.env" ] && source "$HOME/.env"

for tool in docker python3 envsubst scone; do
  command -v "$tool" >/dev/null || { echo "FAIL: '$tool' is required but not on PATH"; exit 1; }
done

# Read the demo's settings from Values.yaml so a caller that rewrites it (CI does) is
# honoured; an environment variable still wins over the file.
value_of() {
  grep -E "^[[:space:]]*$1:" Values.yaml | head -1 |
    sed -E "s/^[^:]*:[[:space:]]*//; s/^['\"]//; s/['\"]$//"
}

# Built and pushed by this script: ttl.sh is anonymous, so the run needs no registry
# credentials of its own for the app image.
export DEMO_IMAGE="$TAG:2h"
export DESTINATION_IMAGE_NAME="$TAG-scone:2h"
export REGISTRY="${REGISTRY:-$(value_of REGISTRY)}"
export IMAGE_PULL_SECRET_NAME="${IMAGE_PULL_SECRET_NAME:-$(value_of IMAGE_PULL_SECRET_NAME)}"
export SCONE_RUNTIME_VERSION="${SCONE_RUNTIME_VERSION:-$(value_of SCONE_RUNTIME_VERSION)}"
export TEE_TYPE="${TEE_TYPE:-$(value_of TEE_TYPE)}"
export SCONE_ENCLAVE="${SCONE_ENCLAVE:-$(value_of SCONE_ENCLAVE)}"
# CI sets CAS_NAME/CAS_NAMESPACE; the demo templates take a single endpoint.
if [ -z "${CAS_ENDPOINT:-}" ]; then
  if [ -n "${CAS_NAME:-}" ]; then
    CAS_ENDPOINT="${CAS_NAME}.${CAS_NAMESPACE:-default}"
  else
    CAS_ENDPOINT="$(value_of CAS_ENDPOINT)"
  fi
fi
export CAS_ENDPOINT
# A fresh namespace per run keeps the CAS session names fresh: re-running into a
# namespace that already has sessions makes CAS keep the ones it already stored.
export NAMESPACE="${NAMESPACE:-$(value_of NAMESPACE)-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
export GOVERNANCE_URL="http://127.0.0.1:$PORT"
export GOVERNANCE_API_TOKEN=stand-in-token

MOCK_PID=""
start_stand_in() {  # $1 = approve | abort
  MOCK_MODE="$1" python3 validate/mock_governance.py "$PORT" >/dev/null &
  MOCK_PID=$!
  sleep 1
}
stop_stand_in() { [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null; MOCK_PID=""; }
trap stop_stand_in EXIT

fail() { echo "FAIL: $*"; exit 1; }

echo "== build + push the app image, render the templates (namespace: $NAMESPACE) =="
docker build -t "$DEMO_IMAGE" . >/dev/null || fail "could not build the app image"
docker push "$DEMO_IMAGE" >/dev/null || fail "could not push the app image"
mkdir -p manifests
envsubst < manifest.template.yaml > manifests/manifest.yaml
envsubst < scone.template.yaml   > manifests/scone.yaml

# ---------------------------------------------------------------- case 1: approved
echo
echo "== CASE 1/2: the signers approve =="
rm -f manifests/manifest.sanitized.yaml
start_stand_in approve
RUST_LOG=info "$BIN" apply -f manifests/scone.yaml || fail "apply failed while the request was approved"
stop_stand_in

out=manifests/manifest.sanitized.yaml
[ -f "$out" ] || fail "no transformed manifest was produced"
signed=$(grep -c 'kind: SignedPolicy' "$out")
submitted=$(grep -c '^name:' manifests/manifest.session.yaml)
[ "$signed" -eq "$submitted" ] || fail "$submitted session(s) submitted but only $signed came back signed"
echo "PASS: $submitted session(s) submitted -> $signed SignedPolicy resource(s) assembled from the signatures"

# Deploy whenever a cluster is reachable (CI always has one); DEPLOY=0 forces the
# flow-only run, DEPLOY=1 requires the deploy.
DEPLOY="${DEPLOY:-auto}"
if [ "$DEPLOY" = "auto" ]; then
  if command -v kubectl >/dev/null && kubectl cluster-info >/dev/null 2>&1; then
    DEPLOY=1
  else
    DEPLOY=0
    echo "SKIP: no reachable cluster, checking the governance flow only"
  fi
fi

if [ "$DEPLOY" = "1" ]; then
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -f "$out" -n "$NAMESPACE" >/dev/null || fail "could not apply the transformed manifest"
  kubectl rollout status deploy/governance-app -n "$NAMESPACE" --timeout=300s || fail "the workload did not become ready"
  # A ready pod is not yet a pod that has printed: the SCONE runtime takes a few seconds
  # to bring the enclave up, so poll the logs instead of reading them once.
  log_deadline=$((SECONDS + 120))
  logs=""
  while [ $SECONDS -lt $log_deadline ]; do
    logs=$(kubectl logs -n "$NAMESPACE" deploy/governance-app --tail=20 2>/dev/null)
    if echo "$logs" | grep -q 'started under a governance-approved policy' &&
       echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy'; then
      break
    fi
    sleep 5
  done
  echo "$logs" | grep -q 'started under a governance-approved policy' \
    || { echo "$logs"; fail "the workload did not report starting under the approved policy"; }
  echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy' \
    || { echo "$logs"; fail "CAS did not deliver the governed secret to the enclave"; }
  echo "PASS: the confidential workload attested and received the governed secret"
fi

# ---------------------------------------------------------------- case 2: rejected
echo
echo "== CASE 2/2: a signer refuses (ABORTED) =="
rm -f manifests/manifest.sanitized.yaml
start_stand_in abort
if RUST_LOG=info "$BIN" apply -f manifests/scone.yaml 2>&1 | tee /tmp/governance-abort.log; then
  fail "apply succeeded even though the signing request was aborted"
fi
stop_stand_in
grep -q 'aborted by a signer' /tmp/governance-abort.log || fail "apply failed, but not because the request was aborted"
[ ! -f "$out" ] || fail "a transformed manifest was produced for an aborted request"
echo "PASS: the request was refused, apply stopped and nothing was produced to deploy"

echo
echo "ALL CASES PASSED"
