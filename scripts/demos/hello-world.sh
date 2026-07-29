#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from /home/daniel/scone-td-build-demos/scripts/../demos/hello-world/README.md.

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

printf "${VIOLET}"
printf '%s\n' '# SCONE: Hello World'
printf '%s\n' ''
printf '%s\n' '[![Hello World Example](../docs/hello-world.gif)](../docs/hello-world.mp4)'
printf '%s\n' ''
printf '%s\n' 'This example shows how to build a simple cloud-native `hello-world` application in Rust, run it natively in Kubernetes, and then deploy a confidential version with SCONE.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:'
printf '%s\n' ''
printf '%s\n' '- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)'
printf '%s\n' '- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Resolve the directory this demo lives in, so every file reference below works regardless of the caller'\''s current working directory, and clean up state left over from a previous run:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Resolve this demo'\''s directory.'
printf '%s\n' 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
printf '%s\n' 'export DEMO_DIR="$SCRIPT_DIR/../../demos/hello-world/"'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm -f "$DEMO_DIR/manifests/storage.json"'
printf "${RESET}"

# Resolve this demo's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEMO_DIR="$SCRIPT_DIR/../../demos/hello-world/"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json"

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
printf '%s\n' 'Load the full variable set with `tplenv`, which also defines the registry credentials used later to create the pull secret:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the Kubernetes namespace if it does not already exist.'
printf '%s\n' 'kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -n ${NAMESPACE} -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"'
printf "${RESET}"

# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -n ${NAMESPACE} -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate the job manifest with the selected image and pull-secret values:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/manifest.job.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.job.yaml"'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.job.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.job.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t $NATIVE_IMAGE_NAME "$DEMO_DIR/app"'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push $NATIVE_IMAGE_NAME'
printf "${RESET}"

# Build the container image.
docker build -t $NATIVE_IMAGE_NAME "$DEMO_DIR/app"
# Push the container image to the registry.
docker push $NATIVE_IMAGE_NAME

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using the registry credentials loaded in step 2.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the pull secret only when it does not already exist, so reruns with a'
printf '%s\n' '# precreated secret do not require registry credentials.'
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \'
printf '%s\n' '    --docker-server="$REGISTRY" \'
printf '%s\n' '    --docker-username="$REGISTRY_USER" \'
printf '%s\n' '    --docker-password="$REGISTRY_TOKEN"'
printf '%s\n' 'fi'
printf "${RESET}"

# Create the pull secret only when it does not already exist, so reruns with a
# precreated secret do not require registry credentials.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server="$REGISTRY" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Run the Native Hello-World Application'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job hello-world -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"'
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Poll for a terminal state instead of `kubectl wait`: this kubectl version only'
printf '%s\n' '# honors the last --for flag when given more than once, so it can'\''t watch for'
printf '%s\n' '# both Complete and Failed in one call, and `wait -n` (used in an earlier'
printf '%s\n' '# version of this check) isn'\''t portable to bash 3.2 or zsh. The Job is'
printf '%s\n' '# configured with backoffLimit: 4 and restartPolicy: OnFailure, so we wait for'
printf '%s\n' '# the Failed *condition* (set only once retries are exhausted), not'
printf '%s\n' '# .status.failed (a per-attempt retry counter that can tick up while the Job'
printf '%s\n' '# is still retrying and will go on to succeed).'
printf '%s\n' 'deadline=$((SECONDS + 300))'
printf '%s\n' 'terminal=""'
printf '%s\n' 'while [[ $SECONDS -lt $deadline ]]; do'
printf '%s\n' '  complete=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='\''{.status.conditions[?(@.type=="Complete")].status}'\'' 2>/dev/null)'
printf '%s\n' '  failed=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='\''{.status.conditions[?(@.type=="Failed")].status}'\'' 2>/dev/null)'
printf '%s\n' '  if [[ "$complete" == "True" ]] || [[ "$failed" == "True" ]]; then'
printf '%s\n' '    terminal=1'
printf '%s\n' '    break'
printf '%s\n' '  fi'
printf '%s\n' '  sleep 2'
printf '%s\n' 'done'
printf '%s\n' 'if [[ -z "$terminal" ]]; then'
printf '%s\n' '  echo "Timed out waiting for job/hello-world to complete or fail" >&2'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' '# Exit non-zero early if the job failed rather than completed.'
printf '%s\n' 'kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='\''{.status.conditions[?(@.type=="Failed")].status}'\'' | grep -q '\''^True$'\'' && { echo "Job hello-world failed"; exit 1; } || true'
printf '%s\n' '# Show logs from the Kubernetes workload.'
printf '%s\n' 'kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

# Poll for a terminal state instead of `kubectl wait`: this kubectl version only
# honors the last --for flag when given more than once, so it can't watch for
# both Complete and Failed in one call, and `wait -n` (used in an earlier
# version of this check) isn't portable to bash 3.2 or zsh. The Job is
# configured with backoffLimit: 4 and restartPolicy: OnFailure, so we wait for
# the Failed *condition* (set only once retries are exhausted), not
# .status.failed (a per-attempt retry counter that can tick up while the Job
# is still retrying and will go on to succeed).
deadline=$((SECONDS + 300))
terminal=""
while [[ $SECONDS -lt $deadline ]]; do
  complete=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
  failed=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
  if [[ "$complete" == "True" ]] || [[ "$failed" == "True" ]]; then
    terminal=1
    break
  fi
  sleep 2
done
if [[ -z "$terminal" ]]; then
  echo "Timed out waiting for job/hello-world to complete or fail" >&2
  exit 1
fi
# Exit non-zero early if the job failed rather than completed.
kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q '^True$' && { echo "Job hello-world failed"; exit 1; } || true
# Show logs from the Kubernetes workload.
kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job hello-world -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Attest SCONE CAS'
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
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 7. Build the Confidential Image and Manifest'
printf '%s\n' ''
printf '%s\n' 'Render the SCONE manifest, which contains everything needed to register the confidential image and transform the Kubernetes manifest in one step:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent'
printf '%s\n' '# Generate the confidential image and sanitized manifest from the SCONE configuration.'
printf '%s\n' 'scone-td-build from -y "$DEMO_DIR/manifests/scone.yaml"'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y "$DEMO_DIR/manifests/scone.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This command registers the confidential image, creates the SCONE session, and produces `$DEMO_DIR/manifests/manifest.prod.sanitized.yaml` from `manifest.job.yaml`.'
printf '%s\n' ''
printf '%s\n' '## 8. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}'
printf '%s\n' '# Poll for a terminal state instead of `kubectl wait`: this kubectl version only'
printf '%s\n' '# honors the last --for flag when given more than once, so it can'\''t watch for'
printf '%s\n' '# both Complete and Failed in one call, and `wait -n` (used in an earlier'
printf '%s\n' '# version of this check) isn'\''t portable to bash 3.2 or zsh. The Job is'
printf '%s\n' '# configured with backoffLimit: 4 and restartPolicy: OnFailure, so we wait for'
printf '%s\n' '# the Failed *condition* (set only once retries are exhausted), not'
printf '%s\n' '# .status.failed (a per-attempt retry counter that can tick up while the Job'
printf '%s\n' '# is still retrying and will go on to succeed).'
printf '%s\n' 'deadline=$((SECONDS + 300))'
printf '%s\n' 'terminal=""'
printf '%s\n' 'while [[ $SECONDS -lt $deadline ]]; do'
printf '%s\n' '  complete=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='\''{.status.conditions[?(@.type=="Complete")].status}'\'' 2>/dev/null)'
printf '%s\n' '  failed=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='\''{.status.conditions[?(@.type=="Failed")].status}'\'' 2>/dev/null)'
printf '%s\n' '  if [[ "$complete" == "True" ]] || [[ "$failed" == "True" ]]; then'
printf '%s\n' '    terminal=1'
printf '%s\n' '    break'
printf '%s\n' '  fi'
printf '%s\n' '  sleep 2'
printf '%s\n' 'done'
printf '%s\n' 'if [[ -z "$terminal" ]]; then'
printf '%s\n' '  echo "Timed out waiting for job/hello-world to complete or fail" >&2'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' '# Exit non-zero early if the job failed rather than completed.'
printf '%s\n' 'kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='\''{.status.conditions[?(@.type=="Failed")].status}'\'' | grep -q '\''^True$'\'' && { echo "Job hello-world failed"; exit 1; } || true'
printf '%s\n' '# Show logs from the Kubernetes workload.'
printf '%s\n' 'kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
# Poll for a terminal state instead of `kubectl wait`: this kubectl version only
# honors the last --for flag when given more than once, so it can't watch for
# both Complete and Failed in one call, and `wait -n` (used in an earlier
# version of this check) isn't portable to bash 3.2 or zsh. The Job is
# configured with backoffLimit: 4 and restartPolicy: OnFailure, so we wait for
# the Failed *condition* (set only once retries are exhausted), not
# .status.failed (a per-attempt retry counter that can tick up while the Job
# is still retrying and will go on to succeed).
deadline=$((SECONDS + 300))
terminal=""
while [[ $SECONDS -lt $deadline ]]; do
  complete=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
  failed=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
  if [[ "$complete" == "True" ]] || [[ "$failed" == "True" ]]; then
    terminal=1
    break
  fi
  sleep 2
done
if [[ -z "$terminal" ]]; then
  echo "Timed out waiting for job/hello-world to complete or fail" >&2
  exit 1
fi
# Exit non-zero early if the job failed rather than completed.
kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q '^True$' && { echo "Job hello-world failed"; exit 1; } || true
# Show logs from the Kubernetes workload.
kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 9. Uninstall `hello-world`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job hello-world -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Automation'
printf '%s\n' ''
printf '%s\n' 'You can run this workflow with:'
printf '%s\n' ''
printf '%s\n' './scripts/hello-world.sh'
printf '%s\n' ''
printf '%s\n' 'It asks for user input unless you set:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"'
printf '%s\n' ''
printf '%s\n' 'This uses values from `hello-world/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.'
printf '%s\n' ''
printf '%s\n' 'If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.'
printf "${RESET}"

