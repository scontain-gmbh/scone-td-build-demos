#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from memos/README.md.

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
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "${VIOLET}"
printf '%s\n' '# Encrypted Volume Demo with memos'
printf '%s\n' ''
printf '%s\n' '## Introduction'
printf '%s\n' ''
printf '%s\n' '[memos](https://github.com/usememos/memos) is an open-source note-taking service. It keeps everything, accounts and notes, in a SQLite database under `/var/opt/memos`, which this demo puts on a `PersistentVolumeClaim`.'
printf '%s\n' ''
printf '%s\n' 'Anyone who can read that storage can read the notes: a node administrator, a backup, a snapshot of the cloud disk. This demo shows how `scone-td-build` closes that gap without changing memos or the manifest:'
printf '%s\n' ''
printf '%s\n' '- The claim stays mounted, and `scone-td-build` binds a SCONE volume to the same path in the CAS session. The SCONE runtime encrypts and authenticates every file memos writes there.'
printf '%s\n' '- CAS generates the key the first time the volume is used and hands it only to the attested memos enclave. Nobody else sees it, not even the cluster administrator.'
printf '%s\n' '- A pod without SCONE that mounts the same claim finds only ciphertext.'
printf '%s\n' '- CAS also records the latest state of the volume, so the enclave refuses an older copy of the files or an emptied claim.'
printf '%s\n' ''
printf '%s\n' 'You first run memos natively and read a note straight off the disk, then run the confidential version and try again.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX resources, a running LAS, and a default `StorageClass`'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`), `docker`, `curl`, `jq` and `openssl`'
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Enter `memos` and remember the previous directory.'
printf '%s\n' 'pushd memos'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm storage.json || true'
printf "${RESET}"

# Enter `memos` and remember the previous directory.
pushd memos
# Remove `storage.json` if it exists.
rm storage.json || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native `memos` image'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.0.8`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS name (for example, `cas`)'
printf '%s\n' '- `$CAS_ENDPOINT` - Address the manifest targets; keep it in sync with `$CAS_NAME`.`$CAS_NAMESPACE` (default: `cas.default`), or set to an external CAS address to run against one'
printf '%s\n' '- `$TEE_TYPE` - Set to `cvm` for CVM mode or `sgx` for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `true` for confidential nodes, or `false` for Kata Pods'
printf '%s\n' '- `$NAMESPACE` - Kubernetes namespace where the demo runs, and CAS namespace of its sessions (default: `memos-demo`)'
printf '%s\n' '- `$ENCLAVE_HEAP` - Enclave heap of the memos container (default and minimum: `2G`)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'The demo account gets a new random password on every run:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Generate the password of the memos demo account.'
printf '%s\n' 'export MEMOS_PASSWORD="$(openssl rand -hex 16)"'
printf '%s\n' '# The port-forward below makes memos reachable here.'
printf '%s\n' 'export MEMOS_URL="http://localhost:5230"'
printf "${RESET}"

# Generate the password of the memos demo account.
export MEMOS_PASSWORD="$(openssl rand -hex 16)"
# The port-forward below makes memos reachable here.
export MEMOS_URL="http://localhost:5230"

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
printf '%s\n' 'Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${CAS_ENDPOINT}` points at an external CAS like `edge.scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Attest the CAS instance before sending encrypted policies.'
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \'
printf '%s\n' '    || scone cas attest ${CAS_ENDPOINT} -C -G -S \'
printf '%s\n' '        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any \'
printf '%s\n' '    || echo "CAS attestation skipped: ${CAS_ENDPOINT} runs in simulation mode, so it cannot produce a DCAP quote"'
printf "${RESET}"

# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \
    || scone cas attest ${CAS_ENDPOINT} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any \
    || echo "CAS attestation skipped: ${CAS_ENDPOINT} runs in simulation mode, so it cannot produce a DCAP quote"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Render the templates:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the Kubernetes manifest of memos.'
printf '%s\n' 'tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml'
printf '%s\n' '# Render the pod that reads the claim without SCONE.'
printf '%s\n' 'tplenv --file disk-reader.template.yaml --create-values-file --output disk-reader.yaml'
printf '%s\n' '# Render the SCONE manifest that drives register plus apply.'
printf '%s\n' 'tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent'
printf "${RESET}"

# Render the Kubernetes manifest of memos.
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml
# Render the pod that reads the claim without SCONE.
tplenv --file disk-reader.template.yaml --create-values-file --output disk-reader.yaml
# Render the SCONE manifest that drives register plus apply.
tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})'
printf '%s\n' '  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Build the Image'
printf '%s\n' ''
printf '%s\n' 'The `Dockerfile` builds memos from its release tag. The upstream image links memos statically, and a static binary cannot be sconified, so the backend is built with the SCONE Go toolchain instead.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t ${IMAGE_NAME} .'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push ${IMAGE_NAME}'
printf "${RESET}"

# Build the container image.
docker build -t ${IMAGE_NAME} .
# Push the container image to the registry.
docker push ${IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate a signing key for confidential binaries if needed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the signing key needs to be generated.'
printf '%s\n' 'if [ ! -f identity.pem ]; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  # Generate the signing key for confidential binaries.'
printf '%s\n' '  openssl genrsa -3 -out identity.pem 3072'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

# Check whether the signing key needs to be generated.
if [ ! -f identity.pem ]; then
  # Print a status message.
  echo "Generating identity.pem ..."
  # Generate the signing key for confidential binaries.
  openssl genrsa -3 -out identity.pem 3072
else
  # Print a status message.
  echo "identity.pem already exists."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. See the Problem: memos Without SCONE'
printf '%s\n' ''
printf '%s\n' 'Clean up previous runs first:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resources if they exist.'
printf '%s\n' 'kubectl delete -f manifest.yaml -n ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'kubectl delete pod disk-reader -n ${NAMESPACE} --ignore-not-found'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s || echo "ok - no memos deployment yet"'
printf '%s\n' '# Stop the previous background process (and its current port-forward child) if still running.'
printf '%s\n' 'kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true'
printf "${RESET}"

# Delete the Kubernetes resources if they exist.
kubectl delete -f manifest.yaml -n ${NAMESPACE} --ignore-not-found
kubectl delete pod disk-reader -n ${NAMESPACE} --ignore-not-found
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s || echo "ok - no memos deployment yet"
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Start the native memos and write a note:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifest.yaml -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Start a self-restarting port-forward; the loop recreates it if the pod bounces.'
printf '%s\n' '# `set -m` puts it in its own process group so cleanup can kill the wrapper and'
printf '%s\n' '# its currently running `kubectl port-forward` child together.'
printf '%s\n' 'set -m'
printf '%s\n' 'while true; do kubectl port-forward deployment/memos 5230:5230 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-5230.pid'
printf '%s\n' 'set +m'
printf '%s\n' ''
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 5 -- ./memos-api.sh signup'
printf '%s\n' '# Write the note this demo protects.'
printf '%s\n' './memos-api.sh post "The safe code is 4711"'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f manifest.yaml -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=240s
# Start a self-restarting port-forward; the loop recreates it if the pod bounces.
# `set -m` puts it in its own process group so cleanup can kill the wrapper and
# its currently running `kubectl port-forward` child together.
set -m
while true; do kubectl port-forward deployment/memos 5230:5230 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-5230.pid
set +m

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 5 -- ./memos-api.sh signup
# Write the note this demo protects.
./memos-api.sh post "The safe code is 4711"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Stop memos, so that SQLite writes everything into its database file, and read the claim from a pod that knows nothing about memos:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Stop memos.'
printf '%s\n' 'kubectl scale deployment memos --replicas=0 -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Read the claim without SCONE.'
printf '%s\n' 'kubectl apply -f disk-reader.yaml -n ${NAMESPACE}'
printf '%s\n' '# Wait for the reader to finish.'
printf '%s\n' 'kubectl wait --for=jsonpath='\''{.status.phase}'\''=Succeeded pod/disk-reader -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Show what the reader found.'
printf '%s\n' 'kubectl logs disk-reader -n ${NAMESPACE} | tee /tmp/memos-native-disk.txt'
printf '%s\n' '# The note is there in plain text.'
printf '%s\n' 'grep -q "memos_prod.db: [1-9]" /tmp/memos-native-disk.txt'
printf "${RESET}"

# Stop memos.
kubectl scale deployment memos --replicas=0 -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s
# Read the claim without SCONE.
kubectl apply -f disk-reader.yaml -n ${NAMESPACE}
# Wait for the reader to finish.
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/disk-reader -n ${NAMESPACE} --timeout=240s
# Show what the reader found.
kubectl logs disk-reader -n ${NAMESPACE} | tee /tmp/memos-native-disk.txt
# The note is there in plain text.
grep -q "memos_prod.db: [1-9]" /tmp/memos-native-disk.txt

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'The first bytes read `SQLite format 3`, and the note is right there in the file.'
printf '%s\n' ''
printf '%s\n' 'Remove the native deployment and its claim:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resources.'
printf '%s\n' 'kubectl delete pod disk-reader -n ${NAMESPACE}'
printf '%s\n' 'kubectl delete -f manifest.yaml -n ${NAMESPACE}'
printf '%s\n' '# Wait for the claim to be gone, so the confidential run starts on a new one.'
printf '%s\n' 'kubectl wait --for=delete pvc/memos-data -n ${NAMESPACE} --timeout=240s || true'
printf '%s\n' '# Stop the previous background process (and its current port-forward child) if still running.'
printf '%s\n' 'kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true'
printf "${RESET}"

# Delete the Kubernetes resources.
kubectl delete pod disk-reader -n ${NAMESPACE}
kubectl delete -f manifest.yaml -n ${NAMESPACE}
# Wait for the claim to be gone, so the confidential run starts on a new one.
kubectl wait --for=delete pvc/memos-data -n ${NAMESPACE} --timeout=240s || true
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Convert the Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Register the image and transform the manifest in one step.'
printf '%s\n' 'scone-td-build apply -f scone.yaml'
printf "${RESET}"

# Register the image and transform the manifest in one step.
scone-td-build apply -f scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '`scone-td-build` reports that the claim becomes an encrypted volume:'
printf '%s\n' ''
printf '%s\n' 'PersistentVolumeClaim memos-data mounted by deployment/memos at /var/opt/memos becomes an encrypted SCONE volume. CAS holds its key in session memos-demo/volume-memos-data.'
printf '%s\n' 'deployment/memos mounts an encrypted volume, so it uses strategy Recreate: a rolling update would open the volume from two pods at once.'
printf '%s\n' ''
printf '%s\n' 'In `manifest.sanitized.yaml` the claim is still mounted at `/var/opt/memos`, and the Deployment uses `strategy: Recreate`. In `manifest.session.yaml`:'
printf '%s\n' ''
printf '%s\n' '- `memos-demo/volume-memos-data` owns the volume and its key, and exports the volume to the memos session.'
printf '%s\n' '- The memos session imports it and binds it at `/var/opt/memos` in the memos image.'
printf '%s\n' ''
printf '%s\n' 'The key belongs to the claim, not to the Deployment. It stays in CAS when you change the manifest and apply again, as long as `metadata.namespace` in `scone.yaml` stays the same.'
printf '%s\n' ''
printf '%s\n' '## 8. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifest.sanitized.yaml -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s'
printf '%s\n' '# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.'
printf '%s\n' 'set -m'
printf '%s\n' 'while true; do kubectl port-forward deployment/memos 5230:5230 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-5230.pid'
printf '%s\n' 'set +m'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f manifest.sanitized.yaml -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s
# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.
set -m
while true; do kubectl port-forward deployment/memos 5230:5230 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-5230.pid
set +m

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 9. Use memos'
printf '%s\n' ''
printf '%s\n' 'memos looks and behaves the same. Create the account and the note again:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- ./memos-api.sh signup'
printf '%s\n' '# Write the note this demo protects.'
printf '%s\n' './memos-api.sh post "The safe code is 4711"'
printf '%s\n' '# Read it back.'
printf '%s\n' './memos-api.sh find "safe code"'
printf "${RESET}"

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- ./memos-api.sh signup
# Write the note this demo protects.
./memos-api.sh post "The safe code is 4711"
# Read it back.
./memos-api.sh find "safe code"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'You can also open <http://localhost:5230> in a browser and sign in as `demo` with the password in `$MEMOS_PASSWORD`.'
printf '%s\n' ''
printf '%s\n' '## 10. Restart the Pod'
printf '%s\n' ''
printf '%s\n' 'The note survives a new pod: the new enclave attests, gets the same key from CAS, and opens the same files.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the pod; the Deployment starts a new one.'
printf '%s\n' 'kubectl delete pod -l app=memos -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s'
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- ./memos-api.sh find "safe code"'
printf "${RESET}"

# Delete the pod; the Deployment starts a new one.
kubectl delete pod -l app=memos -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- ./memos-api.sh find "safe code"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 11. Look at the Disk'
printf '%s\n' ''
printf '%s\n' 'Stop memos and run the same reader as before:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Stop memos.'
printf '%s\n' 'kubectl scale deployment memos --replicas=0 -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Read the claim without SCONE.'
printf '%s\n' 'kubectl apply -f disk-reader.yaml -n ${NAMESPACE}'
printf '%s\n' '# Wait for the reader to finish.'
printf '%s\n' 'kubectl wait --for=jsonpath='\''{.status.phase}'\''=Succeeded pod/disk-reader -n ${NAMESPACE} --timeout=240s'
printf '%s\n' '# Show what the reader found.'
printf '%s\n' 'kubectl logs disk-reader -n ${NAMESPACE} | tee /tmp/memos-confidential-disk.txt'
printf '%s\n' '# The note cannot be found anymore.'
printf '%s\n' 'grep -q "memos_prod.db: 0 matches" /tmp/memos-confidential-disk.txt'
printf '%s\n' '# Delete the reader.'
printf '%s\n' 'kubectl delete pod disk-reader -n ${NAMESPACE}'
printf "${RESET}"

# Stop memos.
kubectl scale deployment memos --replicas=0 -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s
# Read the claim without SCONE.
kubectl apply -f disk-reader.yaml -n ${NAMESPACE}
# Wait for the reader to finish.
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/disk-reader -n ${NAMESPACE} --timeout=240s
# Show what the reader found.
kubectl logs disk-reader -n ${NAMESPACE} | tee /tmp/memos-confidential-disk.txt
# The note cannot be found anymore.
grep -q "memos_prod.db: 0 matches" /tmp/memos-confidential-disk.txt
# Delete the reader.
kubectl delete pod disk-reader -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This time the database starts with random bytes instead of `SQLite format 3`, the note is nowhere in the files, and next to the database there is a `volume.fspf` file: the encrypted metadata the SCONE runtime keeps for the volume.'
printf '%s\n' ''
printf '%s\n' 'Start memos again, and the note is back:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Start memos.'
printf '%s\n' 'kubectl scale deployment memos --replicas=1 -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s'
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- ./memos-api.sh find "safe code"'
printf "${RESET}"

# Start memos.
kubectl scale deployment memos --replicas=1 -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- ./memos-api.sh find "safe code"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 12. Uninstall the Demo'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resources, the claim included.'
printf '%s\n' 'kubectl delete -f manifest.sanitized.yaml -n ${NAMESPACE}'
printf '%s\n' '# Stop the previous background process (and its current port-forward child) if still running.'
printf '%s\n' 'kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true'
printf '%s\n' '# Remove `/tmp/pf-5230.pid` if it exists.'
printf '%s\n' 'rm -f /tmp/pf-5230.pid'
printf '%s\n' '# Return to the previous working directory.'
printf '%s\n' 'popd'
printf "${RESET}"

# Delete the Kubernetes resources, the claim included.
kubectl delete -f manifest.sanitized.yaml -n ${NAMESPACE}
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true
# Remove `/tmp/pf-5230.pid` if it exists.
rm -f /tmp/pf-5230.pid
# Return to the previous working directory.
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'CAS keeps the volume'\''s sessions in the CAS namespace `${NAMESPACE}`, and with them the record of the volume'\''s latest state. A new, empty claim under the same namespace is refused with `The FSPF tag is not fresh - suspected replay attack`, which is the rollback protection at work. To install the demo again from scratch, pick a new `NAMESPACE`.'
printf '%s\n' ''
printf '%s\n' '## What You Can Change'
printf '%s\n' ''
printf '%s\n' 'How the claim is protected is set in the `Apply` of `scone.template.yaml`, under `volumes`; `manifest.template.yaml` stays as it is. Without an entry, the claim is encrypted with rollback protection. For example:'
printf '%s\n' ''
printf '%s\n' '  volumes:'
printf '%s\n' '    - claim: memos-data'
printf '%s\n' '      rollback-protection: false'
printf '%s\n' ''
printf '%s\n' '| Field | Effect |'
printf '%s\n' '|---|---|'
printf '%s\n' '| `encrypted: false` | The claim is mounted unencrypted, as the manifest declares it. |'
printf '%s\n' '| `rollback-protection: false` | The enclave accepts an older copy of the volume, or an empty one, for claims restored from snapshots. |'
printf '%s\n' '| `generation: <n>` | Raising it starts over with a new, empty volume and a new key. The old data cannot be read again. |'
printf '%s\n' ''
printf '%s\n' 'An encrypted volume has a single writer: keep `replicas: 1`. See [Encrypted volumes](https://github.com/scontain/scone-td-build/blob/main/docs/public/apply-manifest.md#encrypted-volumes) for the details.'
printf "${RESET}"

