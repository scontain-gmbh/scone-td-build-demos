#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from demos/governance/README.md.

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

if ! $NON_INTERACTIVE; then
  CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory of the README this script was generated from. The README
# code blocks use it for every file reference so the script works from
# any working directory.
export DEMO_DIR="$(cd "${script_dir}/../../demos/governance" && pwd)"

printf "${VIOLET}"
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# The generated scripts set DEMO_DIR to this demo'\''s directory. When following'
printf '%s\n' '# this README by hand, run the commands from `demos/governance`.'
printf '%s\n' 'export DEMO_DIR="${DEMO_DIR:-$PWD}"'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm -f "$DEMO_DIR/manifests/storage.json" || true'
printf "${RESET}"

# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/governance`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json" || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Seed Values.yaml from the template on first run only.'
printf '%s\n' '[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"'
printf "${RESET}"

# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Export the required environment variable for the next steps.'
printf '%s\n' 'export SIGNER="$(scone self show-session-signing-key)"'
printf "${RESET}"

# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)"'
printf '%s\n' ''
printf '%s\n' 'eval "$(tplenv --file "$DEMO_DIR/gov-credential.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)"'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)"

eval "$(tplenv --file "$DEMO_DIR/gov-credential.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist. A fresh namespace per run keeps the CAS session names fresh: re-running into a namespace that already has sessions makes CAS keep the ones it already stored, so a changed policy would not take effect.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the Kubernetes namespace if it does not already exist.'
printf '%s\n' 'kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null'
printf "${RESET}"

# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Add the Docker registry pull secret if registry credentials are available:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the pull secret already exists.'
printf '%s\n' 'if kubectl get secret "$IMAGE_PULL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  kubectl create secret docker-registry "$IMAGE_PULL_SECRET_NAME" \'
printf '%s\n' '    --namespace "$NAMESPACE" \'
printf '%s\n' '    --docker-server="$REGISTRY" \'
printf '%s\n' '    --docker-username="$REGISTRY_USER" \'
printf '%s\n' '    --docker-password="$REGISTRY_TOKEN" \'
printf '%s\n' '    --dry-run=client -o yaml | kubectl apply -f - >/dev/null'
printf '%s\n' 'fi'
printf "${RESET}"

# Check whether the pull secret already exists.
if kubectl get secret "$IMAGE_PULL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  kubectl create secret docker-registry "$IMAGE_PULL_SECRET_NAME" \
    --namespace "$NAMESPACE" \
    --docker-server="$REGISTRY" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Build and Push the Native Image'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t "$IMAGE_NAME" "$DEMO_DIR/app"'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push "$IMAGE_NAME"'
printf "${RESET}"

# Build the container image.
docker build -t "$IMAGE_NAME" "$DEMO_DIR/app"
# Push the container image to the registry.
docker push "$IMAGE_NAME"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Render the Kubernetes Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the Kubernetes manifest template.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"'
printf "${RESET}"

# Render the Kubernetes manifest template.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Case 1 — Approved Policy'
printf '%s\n' ''
printf '%s\n' 'Start the stand-in policy-signing service in approve mode. It is a stand-in for the service only: it approves automatically with a single key, but it really signs (it delegates to `scone session sign`), so the signatures, the CAS acceptance and the attestation are all real.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Start the governance stand-in in approve mode.'
printf '%s\n' 'MOCK_PORT=8000'
printf '%s\n' 'MOCK_LOG="$(mktemp)"'
printf '%s\n' 'MOCK_POLICY_MODE=APPROVE python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &'
printf '%s\n' 'MOCK_PID=$!'
printf '%s\n' ''
printf '%s\n' '# Wait for the stand-in process to start listening on the configured port'
printf '%s\n' 'deadline=$((SECONDS + 15))'
printf '%s\n' 'server_ready=0'
printf '%s\n' ''
printf '%s\n' 'while [ $SECONDS -lt $deadline ]; do'
printf '%s\n' '  if ! kill -0 "$MOCK_PID" 2>/dev/null; then'
printf '%s\n' '    echo "governance stand-in exited before it started listening:" >&2'
printf '%s\n' '    cat "$MOCK_LOG" >&2'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' ''
printf '%s\n' '  # Check if port is open using nc, curl, or bash'\''s built-in /dev/tcp'
printf '%s\n' '  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then'
printf '%s\n' '    server_ready=1'
printf '%s\n' '    break'
printf '%s\n' '  fi'
printf '%s\n' ''
printf '%s\n' '  sleep 0.2'
printf '%s\n' 'done'
printf '%s\n' ''
printf '%s\n' 'if [ $server_ready -eq 0 ]; then'
printf '%s\n' '  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2'
printf '%s\n' '  cat "$MOCK_LOG" >&2'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf "${RESET}"

# Start the governance stand-in in approve mode.
MOCK_PORT=8000
MOCK_LOG="$(mktemp)"
MOCK_POLICY_MODE=APPROVE python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &
MOCK_PID=$!

# Wait for the stand-in process to start listening on the configured port
deadline=$((SECONDS + 15))
server_ready=0

while [ $SECONDS -lt $deadline ]; do
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "governance stand-in exited before it started listening:" >&2
    cat "$MOCK_LOG" >&2
    exit 1
  fi

  # Check if port is open using nc, curl, or bash's built-in /dev/tcp
  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then
    server_ready=1
    break
  fi

  sleep 0.2
done

if [ $server_ready -eq 0 ]; then
  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2
  cat "$MOCK_LOG" >&2
  exit 1
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Render the SCONE manifest with the dynamic governance URL:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' ''
printf '%s\n' '# Render the SCONE manifest template with the dynamic governance URL.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"'
printf "${RESET}"


# Render the SCONE manifest template with the dynamic governance URL.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Apply the governance flow. This submits the sessions to the stand-in service, waits for approval, and assembles the SignedPolicy resources:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Generate the sanitized manifest from the SCONE configuration.'
printf '%s\n' 'RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml"'
printf "${RESET}"

# Generate the sanitized manifest from the SCONE configuration.
RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Verify that every submitted session came back signed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Verify the transformed manifest was produced.'
printf '%s\n' 'output_manifest="$DEMO_DIR/manifests/manifest.sanitized.yaml"'
printf '%s\n' '[ -f "$output_manifest" ] || { echo "FAIL: no transformed manifest was produced"; exit 1; }'
printf '%s\n' ''
printf '%s\n' '# Count SignedPolicy resources and submitted sessions.'
printf '%s\n' 'signed=$(grep -c '\''kind: SignedPolicy'\'' "$output_manifest")'
printf '%s\n' 'submitted=$(grep -c '\''^name:'\'' "$DEMO_DIR/manifests/manifest.session.yaml")'
printf '%s\n' '[ "$signed" -eq "$submitted" ] || { echo "FAIL: $submitted session(s) submitted but only $signed came back signed"; exit 1; }'
printf '%s\n' 'echo "PASS: $submitted session(s) submitted -> $signed SignedPolicy resource(s) assembled from the signatures"'
printf "${RESET}"

# Verify the transformed manifest was produced.
output_manifest="$DEMO_DIR/manifests/manifest.sanitized.yaml"
[ -f "$output_manifest" ] || { echo "FAIL: no transformed manifest was produced"; exit 1; }

# Count SignedPolicy resources and submitted sessions.
signed=$(grep -c 'kind: SignedPolicy' "$output_manifest")
submitted=$(grep -c '^name:' "$DEMO_DIR/manifests/manifest.session.yaml")
[ "$signed" -eq "$submitted" ] || { echo "FAIL: $submitted session(s) submitted but only $signed came back signed"; exit 1; }
echo "PASS: $submitted session(s) submitted -> $signed SignedPolicy resource(s) assembled from the signatures"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '### Deploy and Verify '
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$output_manifest" -n "$NAMESPACE" '
printf '%s\n' '# Wait for the deployment rollout to complete.'
printf '%s\n' 'kubectl rollout status deploy/governance-app -n "$NAMESPACE" --timeout=300s'
printf '%s\n' ''
printf '%s\n' '# Poll the logs until the workload reports the governed secret.'
printf '%s\n' 'log_deadline=$((SECONDS + 120))'
printf '%s\n' 'logs=""'
printf '%s\n' 'while [ $SECONDS -lt $log_deadline ]; do'
printf '%s\n' '  logs=$(kubectl logs -n "$NAMESPACE" deploy/governance-app --tail=20 2>/dev/null)'
printf '%s\n' '  if echo "$logs" | grep -q '\''started under a governance-approved policy'\'' && \'
printf '%s\n' '      echo "$logs" | grep -q '\''governed secret = delivered-only-under-the-approved-policy'\''; then'
printf '%s\n' '    break'
printf '%s\n' '  fi'
printf '%s\n' '  sleep 5'
printf '%s\n' 'done'
printf '%s\n' 'echo "$logs" | grep -q '\''started under a governance-approved policy'\'' \'
printf '%s\n' '  || { echo "$logs"; echo "FAIL: the workload did not report starting under the approved policy"; exit 1; }'
printf '%s\n' 'echo "$logs" | grep -q '\''governed secret = delivered-only-under-the-approved-policy'\'' \'
printf '%s\n' '  || { echo "$logs"; echo "FAIL: CAS did not deliver the governed secret to the enclave"; exit 1; }'
printf '%s\n' 'echo "PASS: the confidential workload attested and received the governed secret"'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f "$output_manifest" -n "$NAMESPACE" 
# Wait for the deployment rollout to complete.
kubectl rollout status deploy/governance-app -n "$NAMESPACE" --timeout=300s

# Poll the logs until the workload reports the governed secret.
log_deadline=$((SECONDS + 120))
logs=""
while [ $SECONDS -lt $log_deadline ]; do
  logs=$(kubectl logs -n "$NAMESPACE" deploy/governance-app --tail=20 2>/dev/null)
  if echo "$logs" | grep -q 'started under a governance-approved policy' && \
      echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy'; then
    break
  fi
  sleep 5
done
echo "$logs" | grep -q 'started under a governance-approved policy' \
  || { echo "$logs"; echo "FAIL: the workload did not report starting under the approved policy"; exit 1; }
echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy' \
  || { echo "$logs"; echo "FAIL: CAS did not deliver the governed secret to the enclave"; exit 1; }
echo "PASS: the confidential workload attested and received the governed secret"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Stop the stand-in before the next case:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Stop the governance stand-in.'
printf '%s\n' '[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null'
printf '%s\n' '[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"'
printf "${RESET}"

# Stop the governance stand-in.
[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Case 2 — Refused Policy'
printf '%s\n' ''
printf '%s\n' 'Start the stand-in in abort mode and verify that `apply` fails and produces nothing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Start the governance stand-in in abort mode.'
printf '%s\n' 'MOCK_LOG="$(mktemp)"'
printf '%s\n' 'MOCK_POLICY_MODE=REJECT python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &'
printf '%s\n' 'MOCK_PID=$!'
printf '%s\n' ''
printf '%s\n' '# Wait for the stand-in process to start listening on the configured port'
printf '%s\n' 'deadline=$((SECONDS + 15))'
printf '%s\n' 'server_ready=0'
printf '%s\n' ''
printf '%s\n' 'while [ $SECONDS -lt $deadline ]; do'
printf '%s\n' '  if ! kill -0 "$MOCK_PID" 2>/dev/null; then'
printf '%s\n' '    echo "governance stand-in exited before it started listening:" >&2'
printf '%s\n' '    cat "$MOCK_LOG" >&2'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' ''
printf '%s\n' '  # Check if port is open using nc, curl, or bash'\''s built-in /dev/tcp'
printf '%s\n' '  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then'
printf '%s\n' '    server_ready=1'
printf '%s\n' '    break'
printf '%s\n' '  fi'
printf '%s\n' ''
printf '%s\n' '  sleep 0.2'
printf '%s\n' 'done'
printf '%s\n' ''
printf '%s\n' 'if [ $server_ready -eq 0 ]; then'
printf '%s\n' '  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2'
printf '%s\n' '  cat "$MOCK_LOG" >&2'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '# Render the SCONE manifest template with the dynamic governance URL.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"'
printf '%s\n' ''
printf '%s\n' '# Copy and Remove any previous sanitized manifest.'
printf '%s\n' 'cp "$DEMO_DIR/manifests/manifest.sanitized.yaml" "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"'
printf '%s\n' ''
printf '%s\n' 'rm -f "$DEMO_DIR/manifests/manifest.sanitized.yaml"'
printf '%s\n' ''
printf '%s\n' '# Run apply and capture output; expect it to fail.'
printf '%s\n' 'if RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml" 2>&1 | tee /tmp/governance-abort.log; then'
printf '%s\n' '  echo "FAIL: apply succeeded even though the signing request was aborted"'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Verify the failure reason.'
printf '%s\n' 'grep -q '\''aborted by a signer'\'' /tmp/governance-abort.log \'
printf '%s\n' '  || { echo "FAIL: apply failed, but not because the request was aborted"; exit 1; }'
printf '%s\n' ''
printf '%s\n' '[ ! -f "$DEMO_DIR/manifests/manifest.sanitized.yaml" ] \'
printf '%s\n' '  || { echo "FAIL: a transformed manifest was produced for an aborted request"; exit 1; }'
printf '%s\n' ''
printf '%s\n' 'echo "PASS: the request was refused, apply stopped and nothing was produced to deploy"'
printf "${RESET}"

# Start the governance stand-in in abort mode.
MOCK_LOG="$(mktemp)"
MOCK_POLICY_MODE=REJECT python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &
MOCK_PID=$!

# Wait for the stand-in process to start listening on the configured port
deadline=$((SECONDS + 15))
server_ready=0

while [ $SECONDS -lt $deadline ]; do
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "governance stand-in exited before it started listening:" >&2
    cat "$MOCK_LOG" >&2
    exit 1
  fi

  # Check if port is open using nc, curl, or bash's built-in /dev/tcp
  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then
    server_ready=1
    break
  fi

  sleep 0.2
done

if [ $server_ready -eq 0 ]; then
  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2
  cat "$MOCK_LOG" >&2
  exit 1
fi


# Render the SCONE manifest template with the dynamic governance URL.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"

# Copy and Remove any previous sanitized manifest.
cp "$DEMO_DIR/manifests/manifest.sanitized.yaml" "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"

rm -f "$DEMO_DIR/manifests/manifest.sanitized.yaml"

# Run apply and capture output; expect it to fail.
if RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml" 2>&1 | tee /tmp/governance-abort.log; then
  echo "FAIL: apply succeeded even though the signing request was aborted"
  exit 1
fi

# Verify the failure reason.
grep -q 'aborted by a signer' /tmp/governance-abort.log \
  || { echo "FAIL: apply failed, but not because the request was aborted"; exit 1; }

[ ! -f "$DEMO_DIR/manifests/manifest.sanitized.yaml" ] \
  || { echo "FAIL: a transformed manifest was produced for an aborted request"; exit 1; }

echo "PASS: the request was refused, apply stopped and nothing was produced to deploy"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Clean Up'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Stop the governance stand-in.'
printf '%s\n' '[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null'
printf '%s\n' '[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"'
printf '%s\n' 'rm -f /tmp/governance-abort.log'
printf '%s\n' ''
printf '%s\n' 'kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"'
printf "${RESET}"

# Stop the governance stand-in.
[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"
rm -f /tmp/governance-abort.log

kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 8. Against the Real Governance Service'
printf '%s\n' ''
printf '%s\n' 'Point the demo at your instance instead of the stand-in and drop the stand-in steps:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export GOVERNANCE_URL="https://<your-policy-signing-service>"'
printf '%s\n' 'export GOVERNANCE_API_TOKEN="<token bound to your managed access policy>"'
printf "${RESET}"

export GOVERNANCE_URL="https://<your-policy-signing-service>"
export GOVERNANCE_API_TOKEN="<token bound to your managed access policy>"

printf "${VIOLET}"
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
printf "${RESET}"

