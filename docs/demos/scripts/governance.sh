#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs a demo-style shell script generated from demos/governance/README.md.

Options:
  --help             Show this help message and exit.
  --non-interactive  Do not force confirmation for existing tplenv values.
USAGE
}

NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      echo "Error: This script does not accept positional arguments." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Error: This script does not accept positional arguments." >&2
  show_help >&2
  exit 1
fi

unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory of the README this script was generated from. The README
# code blocks use it for every file reference so the script works from
# any working directory.
export DEMO_DIR="$(cd "${script_dir}/../../../demos/governance" && pwd)"

printf "%b" "$LILAC"
printf '%s\n' '# SCONE: Governance-approved CAS Policy'
printf '%s\n' ''
printf '%s\n' 'This example shows `scone-td-build`'\''s governance flow: the generated CAS session policies are not signed locally by whoever runs the build. They are submitted to the policy-signing service, approved by the required signers, and the `SignedPolicy` resources are assembled from the signatures the service returns.'
printf '%s\n' ''
printf '%s\n' 'The demo proves the approval actually gates the deployment, with two cases:'
printf '%s\n' ''
printf '%s\n' '| Case | What happens |'
printf '%s\n' '|---|---|'
printf '%s\n' '| **Approved** | every session comes back signed, the CAS accepts the policies, the confidential workload attests and CAS delivers it a secret the policy grants |'
printf '%s\n' '| **Refused** | a signer aborts the request, `scone-td-build apply` stops with an error and nothing is produced to deploy |'
printf '%s\n' ''
printf '%s\n' 'The app (`app.py`) is deliberately trivial: it just prints the secret CAS hands it. The point of the demo is *how the policy was authorised*.'
printf '%s\n' ''
printf '%s\n' '## How Governance Changes the Flow'
printf '%s\n' ''
printf '%s\n' 'Normally `apply` signs the sessions locally (`scone session sign`). With a `remote:` block it instead:'
printf '%s\n' ''
printf '%s\n' '1. submits the assembled sessions (`POST /api/v1/signing-requests`),'
printf '%s\n' '2. waits while the signers approve,'
printf '%s\n' '3. receives the approved policies plus their signatures, and'
printf '%s\n' '4. builds one `SignedPolicy` per session from those signatures.'
printf '%s\n' ''
printf '%s\n' 'Governance is **SignedPolicy-only**: keep `encrypted-cas-policy: false`. An encrypted (EPOL) policy under governance is rejected with a clear error.'
printf '%s\n' ''
printf '%s\n' '### The Two Modes'
printf '%s\n' ''
printf '%s\n' '- **Inline governance (used here)**: `remote:` and `access_policy:`. The sessions carry that policy and the service signs the assembled sessions.'
printf '%s\n' '- **Remote governance**: `remote:` without `access_policy:`. The service applies the managed policy stored for the API token, and the sessions import the access-policy config-fragment from its `cas-governance` session.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- Docker, `python3`, and the `scone` CLI'
printf '%s\n' '- A `scone-td-build` binary with governance support'
printf '%s\n' '- `tplenv` (`cargo install tplenv --version ">=0.11.0"`)'
printf '%s\n' '- For the deploy check: a Kubernetes cluster with the SCONE stack whose CAS matches `${CAS_NAME}.${CAS_NAMESPACE}`, and a SCONE runtime version that matches that CAS'
printf '%s\n' '- A token for `registry.scontain.com` (the runtime image is pulled during sconification)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Resolve the directory this demo lives in, so every file reference below works regardless of the caller'\''s current working directory:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# The generated scripts set DEMO_DIR to this demo's directory. When following
EOF
)"
pe "$(cat <<'EOF'
# this README by hand, run the commands from `demos/governance`.
EOF
)"
pe "$(cat <<'EOF'
export DEMO_DIR="${DEMO_DIR:-$PWD}"
EOF
)"
pe "$(cat <<'EOF'
# Remove `storage.json` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm -f "$DEMO_DIR/manifests/storage.json" || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Seed Values.yaml from the template on first run only.
EOF
)"
pe "$(cat <<'EOF'
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Export the required environment variable for the next steps.
EOF
)"
pe "$(cat <<'EOF'
export SIGNER="$(scone self show-session-signing-key)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
eval "$(tplenv --file "$DEMO_DIR/gov-credential.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist. A fresh namespace per run keeps the CAS session names fresh: re-running into a namespace that already has sessions makes CAS keep the ones it already stored, so a changed policy would not take effect.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Kubernetes namespace if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Add the Docker registry pull secret if registry credentials are available:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret "$IMAGE_PULL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry "$IMAGE_PULL_SECRET_NAME" \
    --namespace "$NAMESPACE" \
    --docker-server="$REGISTRY" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 3. Build and Push the Native Image'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t "$IMAGE_NAME" "$DEMO_DIR/app"
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push "$IMAGE_NAME"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Render the Kubernetes Manifest'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the Kubernetes manifest template.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Case 1 — Approved Policy'
printf '%s\n' ''
printf '%s\n' 'Start the stand-in policy-signing service in approve mode. It is a stand-in for the service only: it approves automatically with a single key, but it really signs (it delegates to `scone session sign`), so the signatures, the CAS acceptance and the attestation are all real.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Start the governance stand-in in approve mode.
EOF
)"
pe "$(cat <<'EOF'
MOCK_PORT=8000
EOF
)"
pe "$(cat <<'EOF'
MOCK_LOG="$(mktemp)"
EOF
)"
pe "$(cat <<'EOF'
MOCK_POLICY_MODE=APPROVE python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &
EOF
)"
pe "$(cat <<'EOF'
MOCK_PID=$!
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Wait for the stand-in process to start listening on the configured port
EOF
)"
pe "$(cat <<'EOF'
deadline=$((SECONDS + 15))
EOF
)"
pe "$(cat <<'EOF'
server_ready=0
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
while [ $SECONDS -lt $deadline ]; do
EOF
)"
pe "$(cat <<'EOF'
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
    echo "governance stand-in exited before it started listening:" >&2
EOF
)"
pe "$(cat <<'EOF'
    cat "$MOCK_LOG" >&2
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  # Check if port is open using nc, curl, or bash's built-in /dev/tcp
EOF
)"
pe "$(cat <<'EOF'
  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
    server_ready=1
EOF
)"
pe "$(cat <<'EOF'
    break
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  sleep 0.2
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [ $server_ready -eq 0 ]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2
EOF
)"
pe "$(cat <<'EOF'
  cat "$MOCK_LOG" >&2
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Render the SCONE manifest with the dynamic governance URL:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Render the SCONE manifest template with the dynamic governance URL.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Apply the governance flow. This submits the sessions to the stand-in service, waits for approval, and assembles the SignedPolicy resources:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Verify that every submitted session came back signed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Verify the transformed manifest was produced.
EOF
)"
pe "$(cat <<'EOF'
output_manifest="$DEMO_DIR/manifests/manifest.sanitized.yaml"
EOF
)"
pe "$(cat <<'EOF'
[ -f "$output_manifest" ] || { echo "FAIL: no transformed manifest was produced"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Count SignedPolicy resources and submitted sessions.
EOF
)"
pe "$(cat <<'EOF'
signed=$(grep -c 'kind: SignedPolicy' "$output_manifest")
EOF
)"
pe "$(cat <<'EOF'
submitted=$(grep -c '^name:' "$DEMO_DIR/manifests/manifest.session.yaml")
EOF
)"
pe "$(cat <<'EOF'
[ "$signed" -eq "$submitted" ] || { echo "FAIL: $submitted session(s) submitted but only $signed came back signed"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'
echo "PASS: $submitted session(s) submitted -> $signed SignedPolicy resource(s) assembled from the signatures"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Deploy and Verify '
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$output_manifest" -n "$NAMESPACE" 
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deploy/governance-app -n "$NAMESPACE" --timeout=300s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Poll the logs until the workload reports the governed secret.
EOF
)"
pe "$(cat <<'EOF'
log_deadline=$((SECONDS + 120))
EOF
)"
pe "$(cat <<'EOF'
logs=""
EOF
)"
pe "$(cat <<'EOF'
while [ $SECONDS -lt $log_deadline ]; do
EOF
)"
pe "$(cat <<'EOF'
  logs=$(kubectl logs -n "$NAMESPACE" deploy/governance-app --tail=20 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'
  if echo "$logs" | grep -q 'started under a governance-approved policy' && \
      echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy'; then
EOF
)"
pe "$(cat <<'EOF'
    break
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  sleep 5
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'
echo "$logs" | grep -q 'started under a governance-approved policy' \
  || { echo "$logs"; echo "FAIL: the workload did not report starting under the approved policy"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'
echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy' \
  || { echo "$logs"; echo "FAIL: CAS did not deliver the governed secret to the enclave"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'
echo "PASS: the confidential workload attested and received the governed secret"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Stop the stand-in before the next case:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the governance stand-in.
EOF
)"
pe "$(cat <<'EOF'
[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
EOF
)"
pe "$(cat <<'EOF'
[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Case 2 — Refused Policy'
printf '%s\n' ''
printf '%s\n' 'Start the stand-in in abort mode and verify that `apply` fails and produces nothing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Start the governance stand-in in abort mode.
EOF
)"
pe "$(cat <<'EOF'
MOCK_LOG="$(mktemp)"
EOF
)"
pe "$(cat <<'EOF'
MOCK_POLICY_MODE=REJECT python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &
EOF
)"
pe "$(cat <<'EOF'
MOCK_PID=$!
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Wait for the stand-in process to start listening on the configured port
EOF
)"
pe "$(cat <<'EOF'
deadline=$((SECONDS + 15))
EOF
)"
pe "$(cat <<'EOF'
server_ready=0
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
while [ $SECONDS -lt $deadline ]; do
EOF
)"
pe "$(cat <<'EOF'
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
    echo "governance stand-in exited before it started listening:" >&2
EOF
)"
pe "$(cat <<'EOF'
    cat "$MOCK_LOG" >&2
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  # Check if port is open using nc, curl, or bash's built-in /dev/tcp
EOF
)"
pe "$(cat <<'EOF'
  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
    server_ready=1
EOF
)"
pe "$(cat <<'EOF'
    break
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  sleep 0.2
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [ $server_ready -eq 0 ]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2
EOF
)"
pe "$(cat <<'EOF'
  cat "$MOCK_LOG" >&2
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Render the SCONE manifest template with the dynamic governance URL.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Copy and Remove any previous sanitized manifest.
EOF
)"
pe "$(cat <<'EOF'
cp "$DEMO_DIR/manifests/manifest.sanitized.yaml" "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
rm -f "$DEMO_DIR/manifests/manifest.sanitized.yaml"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Run apply and capture output; expect it to fail.
EOF
)"
pe "$(cat <<'EOF'
if RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml" 2>&1 | tee /tmp/governance-abort.log; then
EOF
)"
pe "$(cat <<'EOF'
  echo "FAIL: apply succeeded even though the signing request was aborted"
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Verify the failure reason.
EOF
)"
pe "$(cat <<'EOF'
grep -q 'aborted by a signer' /tmp/governance-abort.log \
  || { echo "FAIL: apply failed, but not because the request was aborted"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
[ ! -f "$DEMO_DIR/manifests/manifest.sanitized.yaml" ] \
  || { echo "FAIL: a transformed manifest was produced for an aborted request"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "PASS: the request was refused, apply stopped and nothing was produced to deploy"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Clean Up'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the governance stand-in.
EOF
)"
pe "$(cat <<'EOF'
[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
EOF
)"
pe "$(cat <<'EOF'
[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"
EOF
)"
pe "$(cat <<'EOF'
rm -f /tmp/governance-abort.log
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Against the Real Governance Service'
printf '%s\n' ''
printf '%s\n' 'Point the demo at your instance instead of the stand-in and drop the stand-in steps:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export GOVERNANCE_URL="https://<your-policy-signing-service>"
EOF
)"
pe "$(cat <<'EOF'
export GOVERNANCE_API_TOKEN="<token bound to your managed access policy>"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Render `manifests/scone.template.yaml` with those values and run `scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml"` directly. The call then **blocks** until the real signers approve the request in the governance website. If the service uses a private CA, add `ca_cert` to the `remote:` block.'
printf '%s\n' ''
printf '%s\n' '## What is Real and What is Simulated'
printf '%s\n' ''
printf '%s\n' '| Real | Simulated |'
printf '%s\n' '|---|---|'
printf '%s\n' '| the sconified confidential image | the service: one key, automatic approval |'
printf '%s\n' '| the signatures (`scone session sign`) | the multi-signer approval workflow |'
printf '%s\n' '| CAS accepting the SignedPolicy resources | |'
printf '%s\n' '| the enclave attesting and receiving its secret | |'
printf "%b" "$RESET"

