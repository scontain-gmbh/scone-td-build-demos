#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from demos/image-signing/README.md.

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
export DEMO_DIR="$(cd "${script_dir}/../../demos/image-signing" && pwd)"

printf "${VIOLET}"
printf '%s\n' '# SCONE: Image Signing'
printf '%s\n' ''
printf '%s\n' 'This example shows how to sign and encrypt a confidential container image using a Sigstore private key, then verify the signature before deploying it to Kubernetes.'
printf '%s\n' ''
printf '%s\n' 'Image signing provides supply chain integrity: only images signed with a trusted private key pass verification. Combined with SCONE encryption, the image layers are also protected at rest in the registry.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- `skopeo` for image inspection and signing'
printf '%s\n' '- [`cosign`](https://docs.sigstore.dev/cosign/system_config/installation/) to cryptographically verify the image signature'
printf '%s\n' '- `openssl` for signing key generation'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:'
printf '%s\n' ''
printf '%s\n' '- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)'
printf '%s\n' '- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Every file reference below goes through `$DEMO_DIR`, this demo'\''s directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# The generated scripts set DEMO_DIR to this demo'\''s directory. When following'
printf '%s\n' '# this README by hand, run the commands from `demos/image-signing`.'
printf '%s\n' 'export DEMO_DIR="${DEMO_DIR:-$PWD}"'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm -f "$DEMO_DIR/manifests/storage.json" || true'
printf "${RESET}"

# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/image-signing`.
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
printf '%s\n' 'eval $(tplenv --file "$DEMO_DIR/../environment-variables.md"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)

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
printf '%s\n' '## 3. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'If you need a pull secret for native and confidential images, create it when missing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the pull secret already exists.'
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
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
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Deploy Key Management Infrastructure'
printf '%s\n' ''
printf '%s\n' 'The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.'
printf '%s\n' ''
printf '%s\n' 'The KBS and key provider run in this demo'\''s own `${NAMESPACE}`, not the shared `trustee` namespace used by a cluster-wide CoCo/Trustee install, so applying and cleaning them up never touches another workload'\''s resources.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the KBS and key-provider manifests into this demo'\''s namespace.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/kbs.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/kbs.yaml"'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/key-provider.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/key-provider.yaml"'
printf '%s\n' '# Deploy the Key Broker Service.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/kbs.yaml"'
printf '%s\n' '# Deploy the key provider.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/key-provider.yaml"'
printf '%s\n' '# Wait for KBS to be ready.'
printf '%s\n' 'kubectl wait --for=condition=available deployment/kbs -n ${NAMESPACE} --timeout=120s'
printf '%s\n' '# Wait for the key provider to be ready.'
printf '%s\n' 'kubectl wait --for=condition=available deployment/keyprovider -n ${NAMESPACE} --timeout=120s'
printf '%s\n' '# Forward the key provider port to localhost so skopeo can reach it.'
printf '%s\n' '# Self-restarting loop avoids killing unrelated processes that may already use port 50000.'
printf '%s\n' 'while true; do kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000 2>/dev/null; sleep 2; done &'
printf '%s\n' 'echo $! > /tmp/pf-keyprovider.pid'
printf '%s\n' '# Give the port-forward a moment to establish the connection.'
printf '%s\n' 'sleep 3'
printf "${RESET}"

# Render the KBS and key-provider manifests into this demo's namespace.
tplenv --file "$DEMO_DIR/manifests/kbs.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/kbs.yaml"
tplenv --file "$DEMO_DIR/manifests/key-provider.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/key-provider.yaml"
# Deploy the Key Broker Service.
kubectl apply -f "$DEMO_DIR/manifests/kbs.yaml"
# Deploy the key provider.
kubectl apply -f "$DEMO_DIR/manifests/key-provider.yaml"
# Wait for KBS to be ready.
kubectl wait --for=condition=available deployment/kbs -n ${NAMESPACE} --timeout=120s
# Wait for the key provider to be ready.
kubectl wait --for=condition=available deployment/keyprovider -n ${NAMESPACE} --timeout=120s
# Forward the key provider port to localhost so skopeo can reach it.
# Self-restarting loop avoids killing unrelated processes that may already use port 50000.
while true; do kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000 2>/dev/null; sleep 2; done &
echo $! > /tmp/pf-keyprovider.pid
# Give the port-forward a moment to establish the connection.
sleep 3

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Generate Signing Keys'
printf '%s\n' ''
printf '%s\n' 'Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed to verify signatures without exposing the private key.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Generate the Ed25519 signing key pair in the format expected by skopeo.'
printf '%s\n' 'skopeo generate-sigstore-key --output-prefix "$DEMO_DIR/app/config/image-signing-key" --passphrase-file "$DEMO_DIR/app/config/empty-passphrase.txt"'
printf "${RESET}"

# Generate the Ed25519 signing key pair in the format expected by skopeo.
skopeo generate-sigstore-key --output-prefix "$DEMO_DIR/app/config/image-signing-key" --passphrase-file "$DEMO_DIR/app/config/empty-passphrase.txt"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Configure the registry to store signatures as sigstore OCI attachments:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Configure sigstore attachments for the registry (user-level, no sudo required).'
printf '%s\n' '# Uses a demo-specific file rather than `default.yaml`, since `registries.d` merges'
printf '%s\n' '# every file in the directory; this avoids overwriting any existing registry config.'
printf '%s\n' 'mkdir -p ~/.config/containers/registries.d'
printf '%s\n' 'cat <<EOF > ~/.config/containers/registries.d/image-signing-demo.yaml'
printf '%s\n' 'docker:'
printf '%s\n' '    ${REGISTRY}:'
printf '%s\n' '        use-sigstore-attachments: true'
printf '%s\n' 'EOF'
printf "${RESET}"

# Configure sigstore attachments for the registry (user-level, no sudo required).
# Uses a demo-specific file rather than `default.yaml`, since `registries.d` merges
# every file in the directory; this avoids overwriting any existing registry config.
mkdir -p ~/.config/containers/registries.d
cat <<EOF > ~/.config/containers/registries.d/image-signing-demo.yaml
docker:
    ${REGISTRY}:
        use-sigstore-attachments: true
EOF

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Build the Native Container Image'
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
printf '%s\n' '## 7. Run the Native Application'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"'
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '# Show logs from the Kubernetes workload.'
printf '%s\n' 'kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job image-signing -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 8. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Before sending encrypted policies to CAS, attest CAS via the Kubernetes API. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Attest the CAS instance before sending encrypted policies.'
printf '%s\n' 'kubectl scone cas attest --namespace "${SCONE_CAS_ADDR#*.}" "${SCONE_CAS_ADDR%%.*}" -C -G -S \'
printf '%s\n' '    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \'
printf '%s\n' '        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any'
printf "${RESET}"

# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace "${SCONE_CAS_ADDR#*.}" "${SCONE_CAS_ADDR%%.*}" -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 9. Build the Confidential Image and Manifest'
printf '%s\n' ''
printf '%s\n' 'Expand a literal `${HOME}` or `~` prefix in `REPO_CREDENTIALS` so the signing step receives an absolute path:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Expand a literal ${HOME} or ~ prefix in REPO_CREDENTIALS without treating the rest of the'
printf '%s\n' '# path as shell code (a path with parentheses or other shell metacharacters must still work).'
printf '%s\n' 'repo_credentials="${REPO_CREDENTIALS}"'
printf '%s\n' 'repo_credentials="${repo_credentials/#\$\{HOME\}/$HOME}"'
printf '%s\n' 'repo_credentials="${repo_credentials/#\~/$HOME}"'
printf '%s\n' 'export REPO_CREDENTIALS="$repo_credentials"'
printf "${RESET}"

# Expand a literal ${HOME} or ~ prefix in REPO_CREDENTIALS without treating the rest of the
# path as shell code (a path with parentheses or other shell metacharacters must still work).
repo_credentials="${REPO_CREDENTIALS}"
repo_credentials="${repo_credentials/#\$\{HOME\}/$HOME}"
repo_credentials="${repo_credentials/#\~/$HOME}"
export REPO_CREDENTIALS="$repo_credentials"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Render the SCONE manifest template, then run `scone-td-build from` to register, sign, encrypt, and apply in one step:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent'
printf '%s\n' '# Generate the confidential image and sanitized manifest from the SCONE configuration.'
printf '%s\n' '(cd "$DEMO_DIR" && OCICRYPT_KEYPROVIDER_CONFIG="$DEMO_DIR/app/config/ocicrypt.conf" \'
printf '%s\n' '  scone-td-build from -y manifests/scone.yaml)'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && OCICRYPT_KEYPROVIDER_CONFIG="$DEMO_DIR/app/config/ocicrypt.conf" \
  scone-td-build from -y manifests/scone.yaml)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 10. Verify Image Signature'
printf '%s\n' ''
printf '%s\n' '`skopeo inspect` only reports image metadata; it never checks a signature against a key. `cosign verify` (compatible with `skopeo`'\''s sigstore signatures) does the actual cryptographic check against the matching public key:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Inspect the signed and encrypted image (metadata only, does not verify anything).'
printf '%s\n' 'skopeo inspect docker://${DESTINATION_IMAGE_NAME}'
printf '%s\n' '# Cryptographically verify the image was signed with our private key. --insecure-ignore-tlog is'
printf '%s\n' '# required because this key pair signs offline and never uploads to the public transparency log.'
printf '%s\n' 'cosign verify --key "$DEMO_DIR/app/config/image-signing-key.pub" --insecure-ignore-tlog ${DESTINATION_IMAGE_NAME}'
printf "${RESET}"

# Inspect the signed and encrypted image (metadata only, does not verify anything).
skopeo inspect docker://${DESTINATION_IMAGE_NAME}
# Cryptographically verify the image was signed with our private key. --insecure-ignore-tlog is
# required because this key pair signs offline and never uploads to the public transparency log.
cosign verify --key "$DEMO_DIR/app/config/image-signing-key.pub" --insecure-ignore-tlog ${DESTINATION_IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 11. Deploy the Signed Confidential Application'
printf '%s\n' ''
printf '%s\n' '> **Blocked:** This step requires `ctd-decoder` to be installed on every cluster node and containerd to be configured with the `ocicrypt` stream processor so it can decrypt the encrypted image layers at pull time. Plain k3d clusters do not include this. See [containers/ocicrypt](https://github.com/containers/ocicrypt) for setup instructions.'
printf '%s\n' '>'
printf '%s\n' '> Once the cluster has `ctd-decoder`, deploy the sanitized manifest (this block is'
printf '%s\n' '> intentionally not part of the generated script, so it does not fail on clusters'
printf '%s\n' '> without `ctd-decoder`):'
printf '%s\n' ''
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "$DEMO_DIR/manifests/manifest.job.sanitized.yaml" -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '# Show logs from the Kubernetes workload.'
printf '%s\n' 'kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf '%s\n' ''
printf '%s\n' '## 12. Clean Up'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Stop the key provider port-forward. Kill the restart loop first so it does not respawn,'
printf '%s\n' '# then the kubectl child it spawned.'
printf '%s\n' 'kill $(cat /tmp/pf-keyprovider.pid 2>/dev/null) 2>/dev/null || true'
printf '%s\n' 'pkill -f "kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000" 2>/dev/null || true'
printf '%s\n' 'rm -f /tmp/pf-keyprovider.pid'
printf '%s\n' '# Delete the key provider and the Key Broker Service.'
printf '%s\n' 'kubectl delete -f "$DEMO_DIR/manifests/key-provider.yaml" --ignore-not-found'
printf '%s\n' 'kubectl delete -f "$DEMO_DIR/manifests/kbs.yaml" --ignore-not-found'
printf '%s\n' '# Remove the sigstore-attachments config this demo added.'
printf '%s\n' 'rm -f ~/.config/containers/registries.d/image-signing-demo.yaml'
printf "${RESET}"

# Stop the key provider port-forward. Kill the restart loop first so it does not respawn,
# then the kubectl child it spawned.
kill $(cat /tmp/pf-keyprovider.pid 2>/dev/null) 2>/dev/null || true
pkill -f "kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000" 2>/dev/null || true
rm -f /tmp/pf-keyprovider.pid
# Delete the key provider and the Key Broker Service.
kubectl delete -f "$DEMO_DIR/manifests/key-provider.yaml" --ignore-not-found
kubectl delete -f "$DEMO_DIR/manifests/kbs.yaml" --ignore-not-found
# Remove the sigstore-attachments config this demo added.
rm -f ~/.config/containers/registries.d/image-signing-demo.yaml

