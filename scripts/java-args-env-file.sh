#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from java-args-env-file/README.md.

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

# ── Working-directory guard (ported from go-args-env-file) ───────────────────

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "${VIOLET}"
printf '%s\n' '# java-args-env-file: Native → SCONE-Protected Kubernetes Demo'
printf '%s\n' ''
printf '%s\n' 'This demo shows how to deploy the `java-args-env-file` Java application on Kubernetes.'
printf '%s\n' 'You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- Docker (with push access to your registry)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:'
printf '%s\n' ''
printf '%s\n' '- `$DEMO_IMAGE`              - Name of the native image to deploy'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME`  - Name of the confidential (SCONE-protected) image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME`  - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_VERSION`           - SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE`           - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME`               - CAS name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE`               - Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE`          - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' '- `$NAMESPACE`              - Namespace name (for example, `java-demo`)'
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
printf '%s\n' '# Change into `java-args-env-file`.'
printf '%s\n' 'pushd java-args-env-file'
printf '%s\n' 'rm -f java-args-env-file-example.json || true'
printf "${RESET}"

# Change into `java-args-env-file`.
pushd java-args-env-file
rm -f java-args-env-file-example.json || true

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Build and Push the Native Docker Image'
printf '%s\n' ''
printf '%s\n' 'The Dockerfile uses a two-stage build: an `eclipse-temurin:21-jdk-alpine` builder stage'
printf '%s\n' 'compiles `Main.java`, and the resulting `.class` file is copied into a minimal'
printf '%s\n' '`eclipse-temurin:21-jre-alpine` runtime image.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t ${DEMO_IMAGE} .'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push ${DEMO_IMAGE}'
printf "${RESET}"

# Build the container image.
docker build -t ${DEMO_IMAGE} .
# Push the container image to the registry.
docker push ${DEMO_IMAGE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Render the Manifests'
printf '%s\n' ''
printf '%s\n' '`tplenv` substitutes environment variables into the template files and writes the final manifests:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file manifests/manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent'
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file manifests/scone.template.yaml    --create-values-file --output manifests/scone.yaml    --indent'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file manifests/manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
# Render the template with the selected values.
tplenv --file manifests/scone.template.yaml    --create-values-file --output manifests/scone.yaml    --indent

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Before applying, confirm that image values were substituted correctly.'
printf '%s\n' ''
printf '%s\n' '## 6. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'If you need a pull secret for native and confidential images, create it when missing.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY`       - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER`  - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching of namespace ${NAMESPACE}  failed -- ignoring this"'
printf "${RESET}"

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching of namespace ${NAMESPACE}  failed -- ignoring this"

printf "${ORANGE}"
printf '%s\n' '# Check whether the pull secret already exists.'
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})'
printf '%s\n' '  # Create the Docker registry pull secret.'
printf '%s\n' '  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \'
printf '%s\n' '    --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

# Check whether the pull secret already exists.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Deploy the Native App'
printf '%s\n' ''
printf '%s\n' 'Apply the manifest and follow the pod logs to confirm the app prints arguments,'
printf '%s\n' 'environment variables, and the contents of the ConfigMap and Secret files.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifests/manifest.yaml -n ${NAMESPACE}'
printf '%s\n' '# Follow logs from the Kubernetes workload.'
printf '%s\n' 'retry-spinner --retries 10 --wait 2 -- kubectl logs deployment/java-args-env-file -n "${NAMESPACE}" --follow'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f manifests/manifest.yaml -n ${NAMESPACE}
# Follow logs from the Kubernetes workload.
retry-spinner --retries 10 --wait 2 -- kubectl logs deployment/java-args-env-file -n "${NAMESPACE}" --follow

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Your container should print the command-line args, all environment variables,'
printf '%s\n' 'the contents of `/config/configs.yaml`, and `/config/secrets`.'
printf '%s\n' ''
printf '%s\n' 'Clean up the native deployment before moving on:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f manifests/manifest.yaml -n ${NAMESPACE}'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete -f manifests/manifest.yaml -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 8. Prepare and Apply the SCONE Manifest'
printf '%s\n' ''
printf '%s\n' 'First, attest the CAS so the local SCONE CLI has the correct session encryption key. The `|| echo` makes this non-fatal because the public CAS may already be cached as trustworthy from an earlier run.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Attest the CAS instance before sending encrypted policies.'
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."'
printf "${RESET}"

# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then build the confidential image and generate the SCONE session from `manifests/scone.yaml`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Generate the confidential image and sanitized manifest from the SCONE configuration.'
printf '%s\n' 'scone-td-build from -y manifests/scone.yaml'
printf "${RESET}"

# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y manifests/scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Generates a SCONE session'
printf '%s\n' '- Attaches the session to your manifest'
printf '%s\n' '- Produces `manifests/manifest.prod.sanitized.yaml`'
printf '%s\n' ''
printf '%s\n' '## 9. Deploy the SCONE-Protected App'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifests/manifest.prod.sanitized.yaml -n ${NAMESPACE}'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f manifests/manifest.prod.sanitized.yaml -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 10. View Logs'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Follow logs from the Kubernetes workload.'
printf '%s\n' 'retry-spinner -- kubectl logs deployment/java-args-env-file -n "${NAMESPACE}" --follow'
printf "${RESET}"

# Follow logs from the Kubernetes workload.
retry-spinner -- kubectl logs deployment/java-args-env-file -n "${NAMESPACE}" --follow

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 11. Clean Up'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f manifests/manifest.prod.sanitized.yaml -n ${NAMESPACE}'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete -f manifests/manifest.prod.sanitized.yaml -n ${NAMESPACE}
popd
