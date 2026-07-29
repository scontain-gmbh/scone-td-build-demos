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

Runs a demo-style shell script generated from /home/daniel/scone-td-build-demos/scripts/../demos/image-signing/README.md.

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

printf "%b" "$LILAC"
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
printf '%s\n' 'Resolve the directory this demo lives in, so every file reference below works regardless of the caller'\''s current working directory, and clean up state left over from a previous run:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Resolve this demo's directory.
EOF
)"
pe "$(cat <<'EOF'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EOF
)"
pe "$(cat <<'EOF'
export DEMO_DIR="$SCRIPT_DIR/../../demos/image-signing/"
EOF
)"
pe "$(cat <<'EOF'
# Remove `storage.json` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm -f "$DEMO_DIR/storage.json" || true
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
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --eval-export-values --output /dev/null)
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
printf '%s\n' '## 3. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'If you need a pull secret for native and confidential images, create it when missing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
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
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  # Create the Docker registry pull secret.
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Deploy Key Management Infrastructure'
printf '%s\n' ''
printf '%s\n' 'The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.'
printf '%s\n' ''
printf '%s\n' 'The KBS and key provider run in this demo'\''s own `${NAMESPACE}`, not the shared `trustee` namespace used by a cluster-wide CoCo/Trustee install, so applying and cleaning them up never touches another workload'\''s resources.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the KBS and key-provider manifests into this demo's namespace.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/kbs.template.yaml" --create-values-file --output "$DEMO_DIR/manifests/kbs.yaml"
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/key-provider.template.yaml" --create-values-file --output "$DEMO_DIR/manifests/key-provider.yaml"
EOF
)"
pe "$(cat <<'EOF'
# Deploy the Key Broker Service.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/kbs.yaml"
EOF
)"
pe "$(cat <<'EOF'
# Deploy the key provider.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/key-provider.yaml"
EOF
)"
pe "$(cat <<'EOF'
# Wait for KBS to be ready.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=available deployment/kbs -n ${NAMESPACE} --timeout=120s
EOF
)"
pe "$(cat <<'EOF'
# Wait for the key provider to be ready.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=available deployment/keyprovider -n ${NAMESPACE} --timeout=120s
EOF
)"
pe "$(cat <<'EOF'
# Forward the key provider port to localhost so skopeo can reach it.
EOF
)"
pe "$(cat <<'EOF'
# Self-restarting loop avoids killing unrelated processes that may already use port 50000.
EOF
)"
pe "$(cat <<'EOF'
while true; do kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000 2>/dev/null; sleep 2; done &
EOF
)"
pe "$(cat <<'EOF'
echo $! > /tmp/pf-keyprovider.pid
EOF
)"
pe "$(cat <<'EOF'
# Give the port-forward a moment to establish the connection.
EOF
)"
pe "$(cat <<'EOF'
sleep 3
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Generate Signing Keys'
printf '%s\n' ''
printf '%s\n' 'Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed to verify signatures without exposing the private key.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the Ed25519 signing key pair in the format expected by skopeo.
EOF
)"
pe "$(cat <<'EOF'
skopeo generate-sigstore-key --output-prefix "$DEMO_DIR/app/config/image-signing-key" --passphrase-file "$DEMO_DIR/app/config/empty-passphrase.txt"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Configure the registry to store signatures as sigstore OCI attachments:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Configure sigstore attachments for the registry (user-level, no sudo required).
EOF
)"
pe "$(cat <<'EOF'
# Uses a demo-specific file rather than `default.yaml`, since `registries.d` merges
EOF
)"
pe "$(cat <<'EOF'
# every file in the directory; this avoids overwriting any existing registry config.
EOF
)"
pe "$(cat <<'EOF'
mkdir -p ~/.config/containers/registries.d
EOF
)"
pe "$(cat <<'EOF'
cat <<EOF > ~/.config/containers/registries.d/image-signing-demo.yaml
EOF
)"
pe "$(cat <<'EOF'
docker:
EOF
)"
pe "$(cat <<'EOF'
    ${REGISTRY}:
EOF
)"
pe "$(cat <<'EOF'
        use-sigstore-attachments: true
EOF
)"
pe "$(cat <<'EOF'
EOF
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t $NATIVE_IMAGE_NAME "$DEMO_DIR/app"
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $NATIVE_IMAGE_NAME
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Run the Native Application'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
EOF
)"
pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job image-signing -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Before sending encrypted policies to CAS, attest CAS via the Kubernetes API. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Attest the CAS instance before sending encrypted policies.
EOF
)"
pe "$(cat <<'EOF'
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 9. Build the Confidential Image and Manifest'
printf '%s\n' ''
printf '%s\n' 'Expand a literal `${HOME}` or `~` prefix in `REPO_CREDENTIALS` so the signing step receives an absolute path:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Expand a literal ${HOME} or ~ prefix in REPO_CREDENTIALS without treating the rest of the
EOF
)"
pe "$(cat <<'EOF'
# path as shell code (a path with parentheses or other shell metacharacters must still work).
EOF
)"
pe "$(cat <<'EOF'
repo_credentials="${REPO_CREDENTIALS}"
EOF
)"
pe "$(cat <<'EOF'
repo_credentials="${repo_credentials/#\$\{HOME\}/$HOME}"
EOF
)"
pe "$(cat <<'EOF'
repo_credentials="${repo_credentials/#\~/$HOME}"
EOF
)"
pe "$(cat <<'EOF'
export REPO_CREDENTIALS="$repo_credentials"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Render the SCONE manifest template, then run `scone-td-build from` to register, sign, encrypt, and apply in one step:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
EOF
)"
pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
OCICRYPT_KEYPROVIDER_CONFIG="$DEMO_DIR/app/config/ocicrypt.conf" \
  scone-td-build from -y "$DEMO_DIR/manifests/scone.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 10. Verify Image Signature'
printf '%s\n' ''
printf '%s\n' '`skopeo inspect` only reports image metadata; it never checks a signature against a key. `cosign verify` (compatible with `skopeo`'\''s sigstore signatures) does the actual cryptographic check against the matching public key:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Inspect the signed and encrypted image (metadata only, does not verify anything).
EOF
)"
pe "$(cat <<'EOF'
skopeo inspect docker://${DESTINATION_IMAGE_NAME}
EOF
)"
pe "$(cat <<'EOF'
# Cryptographically verify the image was signed with our private key. --insecure-ignore-tlog is
EOF
)"
pe "$(cat <<'EOF'
# required because this key pair signs offline and never uploads to the public transparency log.
EOF
)"
pe "$(cat <<'EOF'
cosign verify --key "$DEMO_DIR/app/config/image-signing-key.pub" --insecure-ignore-tlog ${DESTINATION_IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 11. Deploy the Signed Confidential Application'
printf '%s\n' ''
printf '%s\n' '> **Blocked:** This step requires `ctd-decoder` to be installed on every cluster node and containerd to be configured with the `ocicrypt` stream processor so it can decrypt the encrypted image layers at pull time. Plain k3d clusters do not include this. See [containers/ocicrypt](https://github.com/containers/ocicrypt) for setup instructions.'
printf '%s\n' '>'
printf '%s\n' '> Once the cluster has `ctd-decoder`, deploy the sanitized manifest:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.sanitized.yaml" -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 12. Clean Up'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the key provider port-forward. Kill the restart loop first so it does not respawn,
EOF
)"
pe "$(cat <<'EOF'
# then the kubectl child it spawned.
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-keyprovider.pid 2>/dev/null) 2>/dev/null || true
EOF
)"
pe "$(cat <<'EOF'
pkill -f "kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000" 2>/dev/null || true
EOF
)"
pe "$(cat <<'EOF'
rm -f /tmp/pf-keyprovider.pid
EOF
)"
pe "$(cat <<'EOF'
# Delete the key provider and the Key Broker Service.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f "$DEMO_DIR/manifests/key-provider.yaml" --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f "$DEMO_DIR/manifests/kbs.yaml" --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
# Remove the sigstore-attachments config this demo added.
EOF
)"
pe "$(cat <<'EOF'
rm -f ~/.config/containers/registries.d/image-signing-demo.yaml
EOF
)"

