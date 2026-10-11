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

Runs a demo-style shell script generated from web-server/README.md.

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
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "%b" "$LILAC"
printf '%s\n' '# Web Server Demo'
printf '%s\n' ''
printf '%s\n' '## Introduction'
printf '%s\n' ''
printf '%s\n' 'This Rust application is a minimal web service built with [Axum](https://github.com/tokio-rs/axum). It is intentionally small and easy to follow.'
printf '%s\n' ''
printf '%s\n' '[![Web-Server Example](../docs/web-server.gif)](../docs/web-server.mp4)'
printf '%s\n' ''
printf '%s\n' '## Endpoints'
printf '%s\n' ''
printf '%s\n' '- **Generate password (`/gen`)**'
printf '%s\n' '  - Generates a random alphanumeric password.'
printf '%s\n' '  - Example response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "password": "aBcD1234EeFgH5678"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print path (`/path`)**'
printf '%s\n' '  - Reads files from `/config` and returns file names and contents.'
printf '%s\n' '  - Example response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "name": "file1.txt",'
printf '%s\n' '    "content": "This is the content of file1.txt.\n..."'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print environment variable (`/env/:env`)**'
printf '%s\n' '  - Returns the value of the requested environment variable.'
printf '%s\n' '  - Example response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "value": "your_env_value_here"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Assume you start in `scone-td-build-demos`, then switch to this demo:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Enter `web-server` and remember the previous directory.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
pushd web-server
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove `storage.json` if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm storage.json || true
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native `web-server` image'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.0.8`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS name (for example, `cas`)'
printf '%s\n' '- `$CAS_ENDPOINT` - Address the manifest targets; keep it in sync with `$CAS_NAME`.`$CAS_NAMESPACE` (default: `cas.default`), or set to an external CAS address to run against one'
printf '%s\n' '- `$TEE_TYPE` - Set to `cvm` for CVM mode or `sgx` for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `true` for confidential nodes, or `false` for Kata Pods'
printf '%s\n' '- `$NAMESPACE` - Kubernetes namespace where the demo runs (default: `default`)'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Load environment variables from the tplenv definition file.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create the Kubernetes namespace if it does not already exist.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${CAS_ENDPOINT}` points at an external CAS like `edge.scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Attest the CAS instance before sending encrypted policies.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \
    || scone cas attest ${CAS_ENDPOINT} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any \
    || echo "CAS attestation skipped: ${CAS_ENDPOINT} runs in simulation mode, so it cannot produce a DCAP quote"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, review the output for detected issues and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' 'Render the manifest template:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render the template with the selected values.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render the SCONE manifest that drives register plus apply.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
else
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Build and Register the Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the native image:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Build the container image.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker build -t ${IMAGE_NAME} .
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Push the container image to the registry.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker push ${IMAGE_NAME}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate a signing key for confidential binaries if needed:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Check whether the signing key needs to be generated.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if [ ! -f identity.pem ]; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Generating identity.pem ..."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Generate the signing key for confidential binaries.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  openssl genrsa -3 -out identity.pem 3072
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
else
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "identity.pem already exists."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '`scone.yaml` declares the `Register` for this image and the `Apply` that transforms the'
printf '%s\n' 'manifest, so both run from a single command in the conversion step below.'
printf '%s\n' ''
printf '%s\n' '## 6. Test the Native Manifest (Optional)'
printf '%s\n' ''
printf '%s\n' 'Clean up previous runs first:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete deployment web-server -n ${NAMESPACE} || echo "ok - no web-server deployment yet"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the Kubernetes resource to reach the expected state.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s || echo "ok - no web-server deployment yet"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the previous background process (and its current port-forward child) if still running.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Deploy and test:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -f manifest.yaml -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the Kubernetes resource to reach the expected state.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Start a self-restarting port-forward; the loop recreates it if the pod bounces.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# its currently running `kubectl port-forward` child together: killing only the
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# wrapper's PID leaves that child running and the port still bound.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
set -m
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
set +m
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/env/MY_POD_IP
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Run the demo test script.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
./test.sh
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -f manifest.yaml -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the Kubernetes resource to reach the expected state.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the previous background process (and its current port-forward child) if still running.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove `/tmp/pf-8000.pid` if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm /tmp/pf-8000.pid
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Convert the Manifest'
printf '%s\n' ''
printf '%s\n' 'If you want to inspect registration details, see [register-image](https://github.com/scontain/k8s-scone/blob/main/register-image.md).'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Register the image and transform the manifest in one step.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
scone-td-build apply -f scone.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -f manifest.sanitized.yaml -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '## 9. Run the Demo'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the Kubernetes resource to reach the expected state.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# A ready pod does not always mean the port is immediately available.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait briefly for the service to become reachable.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
sleep 20
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# its currently running `kubectl port-forward` child together: killing only the
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# wrapper's PID leaves that child running and the port still bound.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
set -m
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
set +m
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Send test requests:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/gen
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Run the demo test script.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
./test.sh
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 10. Uninstall the Demo'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -f manifest.sanitized.yaml -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the previous background process (and its current port-forward child) if still running.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove `/tmp/pf-8000.pid` if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm /tmp/pf-8000.pid
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Return to the previous working directory.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
popd
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This demo provides a simple but functional Rust web service that you can extend as needed.'
printf "%b" "$RESET"

