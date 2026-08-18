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

Runs a demo-style shell script generated from demos/web-server/README.md.

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
export DEMO_DIR="$(cd "${script_dir}/../demos/web-server" && pwd)"

printf "%b" "$LILAC"
printf '%s\n' '# Web Server Demo'
printf '%s\n' ''
printf '%s\n' '## Introduction'
printf '%s\n' ''
printf '%s\n' 'This Rust application is a minimal web service built with [Axum](https://github.com/tokio-rs/axum). It is intentionally small and easy to follow.'
printf '%s\n' ''
printf '%s\n' '[![Web-Server Example](../../docs/web-server.gif)](../../docs/web-server.mp4)'
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
printf '%s\n' 'Every file reference below goes through `$DEMO_DIR`, this demo'\''s directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# The generated scripts set DEMO_DIR to this demo's directory. When following
EOF
)"
pe "$(cat <<'EOF'
# this README by hand, run the commands from `demos/web-server`.
EOF
)"
pe "$(cat <<'EOF'
export DEMO_DIR="${DEMO_DIR:-$PWD}"
EOF
)"
pe "$(cat <<'EOF'

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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Kubernetes namespace if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Attest the CAS instance before sending encrypted policies.
EOF
)"
pe "$(cat <<'EOF'
kubectl scone cas attest --namespace "${SCONE_CAS_ADDR#*.}" "${SCONE_CAS_ADDR%%.*}" -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, review the output for detected issues and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' 'Render the manifest template:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
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
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Build and Register the Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the native image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push ${NATIVE_IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate a signing key for confidential binaries if needed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the signing key needs to be generated.
EOF
)"
pe "$(cat <<'EOF'
if [ ! -f "$DEMO_DIR/identity.pem" ]; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Generating identity.pem ..."
EOF
)"
pe "$(cat <<'EOF'
  # Generate the signing key for confidential binaries.
EOF
)"
pe "$(cat <<'EOF'
  openssl genrsa -3 -out "$DEMO_DIR/identity.pem" 3072
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "identity.pem already exists."
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate the SCONE config from its template, then run `scone-td-build` to produce the confidential image and sanitized manifest:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
EOF
)"
pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If you want to inspect registration details, see [register-image](https://github.com/scontain/k8s-scone/blob/main/register-image.md).'
printf '%s\n' ''
printf '%s\n' '## 6. Test the Native Manifest (Optional)'
printf '%s\n' ''
printf '%s\n' 'Clean up previous runs first:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete deployment web-server -n ${NAMESPACE} || echo "ok - no web-server deployment yet"
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s || echo "ok - no web-server deployment yet"
EOF
)"
pe "$(cat <<'EOF'
# Stop the previous background process (and its current port-forward child) if still running.
EOF
)"
pe "$(cat <<'EOF'
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Deploy and test:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s
EOF
)"
pe "$(cat <<'EOF'
# Start a self-restarting port-forward; the loop recreates it if the pod bounces.
EOF
)"
pe "$(cat <<'EOF'
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
EOF
)"
pe "$(cat <<'EOF'
# its currently running `kubectl port-forward` child together: killing only the
EOF
)"
pe "$(cat <<'EOF'
# wrapper's PID leaves that child running and the port still bound.
EOF
)"
pe "$(cat <<'EOF'
set -m
EOF
)"
pe "$(cat <<'EOF'
while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid
EOF
)"
pe "$(cat <<'EOF'
set +m
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
EOF
)"
pe "$(cat <<'EOF'
# Run the demo test script.
EOF
)"
pe "$(cat <<'EOF'
"$DEMO_DIR/test.sh"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s
EOF
)"
pe "$(cat <<'EOF'
# Stop the previous background process (and its current port-forward child) if still running.
EOF
)"
pe "$(cat <<'EOF'
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Remove `/tmp/pf-8000.pid` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-8000.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '## 8. Run the Demo'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s
EOF
)"
pe "$(cat <<'EOF'
# A ready pod does not always mean the port is immediately available.
EOF
)"
pe "$(cat <<'EOF'
# Wait briefly for the service to become reachable.
EOF
)"
pe "$(cat <<'EOF'
sleep 20
EOF
)"
pe "$(cat <<'EOF'
# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.
EOF
)"
pe "$(cat <<'EOF'
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
EOF
)"
pe "$(cat <<'EOF'
# its currently running `kubectl port-forward` child together: killing only the
EOF
)"
pe "$(cat <<'EOF'
# wrapper's PID leaves that child running and the port still bound.
EOF
)"
pe "$(cat <<'EOF'
set -m
EOF
)"
pe "$(cat <<'EOF'
while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid
EOF
)"
pe "$(cat <<'EOF'
set +m
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Send test requests:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
EOF
)"
pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/gen
EOF
)"
pe "$(cat <<'EOF'
# Run the demo test script.
EOF
)"
pe "$(cat <<'EOF'
"$DEMO_DIR/test.sh"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 9. Uninstall the Demo'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Stop the previous background process (and its current port-forward child) if still running.
EOF
)"
pe "$(cat <<'EOF'
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Remove `/tmp/pf-8000.pid` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-8000.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This demo provides a simple but functional Rust web service that you can extend as needed.'
printf "%b" "$RESET"

