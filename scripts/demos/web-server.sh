#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from demos/web-server/README.md.

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
export DEMO_DIR="$(cd "${script_dir}/../../demos/web-server" && pwd)"

printf "${VIOLET}"
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# The generated scripts set DEMO_DIR to this demo'\''s directory. When following'
printf '%s\n' '# this README by hand, run the commands from `demos/web-server`.'
printf '%s\n' 'export DEMO_DIR="${DEMO_DIR:-$PWD}"'
printf '%s\n' ''
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm -f "$DEMO_DIR/storage.json" || true'
printf "${RESET}"

# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/web-server`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"

# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/storage.json" || true

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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the Kubernetes namespace if it does not already exist.'
printf '%s\n' 'kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"'
printf "${RESET}"

# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Attest the CAS instance before sending encrypted policies.'
printf '%s\n' 'kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \'
printf '%s\n' '    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \'
printf '%s\n' '        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any'
printf "${RESET}"

# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, review the output for detected issues and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' 'Render the manifest template:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Build and Register the Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the native image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push ${NATIVE_IMAGE_NAME}'
printf "${RESET}"

# Build the container image.
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
# Push the container image to the registry.
docker push ${NATIVE_IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate a signing key for confidential binaries if needed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the signing key needs to be generated.'
printf '%s\n' 'if [ ! -f "$DEMO_DIR/identity.pem" ]; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  # Generate the signing key for confidential binaries.'
printf '%s\n' '  openssl genrsa -3 -out "$DEMO_DIR/identity.pem" 3072'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

# Check whether the signing key needs to be generated.
if [ ! -f "$DEMO_DIR/identity.pem" ]; then
  # Print a status message.
  echo "Generating identity.pem ..."
  # Generate the signing key for confidential binaries.
  openssl genrsa -3 -out "$DEMO_DIR/identity.pem" 3072
else
  # Print a status message.
  echo "identity.pem already exists."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate the SCONE config from its template, then run `scone-td-build` to produce the confidential image and sanitized manifest:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent'
printf '%s\n' '# Generate the confidential image and sanitized manifest from the SCONE configuration.'
printf '%s\n' '(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If you want to inspect registration details, see [register-image](https://github.com/scontain/k8s-scone/blob/main/register-image.md).'
printf '%s\n' ''
printf '%s\n' '## 6. Test the Native Manifest (Optional)'
printf '%s\n' ''
printf '%s\n' 'Clean up previous runs first:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete deployment web-server -n ${NAMESPACE} || echo "ok - no web-server deployment yet"'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s || echo "ok - no web-server deployment yet"'
printf '%s\n' '# Stop the previous background process (and its current port-forward child) if still running.'
printf '%s\n' 'kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete deployment web-server -n ${NAMESPACE} || echo "ok - no web-server deployment yet"
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s || echo "ok - no web-server deployment yet"
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Deploy and test:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Start a self-restarting port-forward; the loop recreates it if the pod bounces.'
printf '%s\n' '# `set -m` puts it in its own process group so cleanup can kill the wrapper and'
printf '%s\n' '# its currently running `kubectl port-forward` child together: killing only the'
printf '%s\n' '# wrapper'\''s PID leaves that child running and the port still bound.'
printf '%s\n' 'set -m'
printf '%s\n' 'while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid'
printf '%s\n' 'set +m'
printf '%s\n' ''
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/env/MY_POD_IP'
printf '%s\n' '# Run the demo test script.'
printf '%s\n' '"$DEMO_DIR/test.sh"'
printf '%s\n' ''
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Stop the previous background process (and its current port-forward child) if still running.'
printf '%s\n' 'kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true'
printf '%s\n' '# Remove `/tmp/pf-8000.pid` if it exists.'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s
# Start a self-restarting port-forward; the loop recreates it if the pod bounces.
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
# its currently running `kubectl port-forward` child together: killing only the
# wrapper's PID leaves that child running and the port still bound.
set -m
while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid
set +m

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
# Run the demo test script.
"$DEMO_DIR/test.sh"

# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '## 8. Run the Demo'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# A ready pod does not always mean the port is immediately available.'
printf '%s\n' '# Wait briefly for the service to become reachable.'
printf '%s\n' 'sleep 20'
printf '%s\n' '# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.'
printf '%s\n' '# `set -m` puts it in its own process group so cleanup can kill the wrapper and'
printf '%s\n' '# its currently running `kubectl port-forward` child together: killing only the'
printf '%s\n' '# wrapper'\''s PID leaves that child running and the port still bound.'
printf '%s\n' 'set -m'
printf '%s\n' 'while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid'
printf '%s\n' 'set +m'
printf "${RESET}"

# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="web-server" -n ${NAMESPACE} --timeout=240s
# A ready pod does not always mean the port is immediately available.
# Wait briefly for the service to become reachable.
sleep 20
# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
# its currently running `kubectl port-forward` child together: killing only the
# wrapper's PID leaves that child running and the port still bound.
set -m
while true; do kubectl port-forward deployment/web-server 8000:8000 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-8000.pid
set +m

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send test requests:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path'
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/gen'
printf '%s\n' '# Run the demo test script.'
printf '%s\n' '"$DEMO_DIR/test.sh"'
printf "${RESET}"

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/gen
# Run the demo test script.
"$DEMO_DIR/test.sh"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 9. Uninstall the Demo'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}'
printf '%s\n' '# Stop the previous background process (and its current port-forward child) if still running.'
printf '%s\n' 'kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true'
printf '%s\n' '# Remove `/tmp/pf-8000.pid` if it exists.'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This demo provides a simple but functional Rust web service that you can extend as needed.'
printf "${RESET}"

