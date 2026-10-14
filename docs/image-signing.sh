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

Runs a demo-style shell script generated from image-signing/README.md.

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
printf '%s\n' '# SCONE: Image Signing'
printf '%s\n' ''
printf '%s\n' 'This example shows how to sign and encrypt a confidential container image using a Sigstore private'
printf '%s\n' 'key, then verify the signature before deploying it to Kubernetes.'
printf '%s\n' ''
printf '%s\n' 'Image signing provides supply chain integrity: only images signed with a trusted private key pass'
printf '%s\n' 'verification. Combined with SCONE encryption, the image layers are also protected at rest in the'
printf '%s\n' 'registry.'
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
printf '%s\n' 'We assume you start in `scone-td-build-demos`:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Enter `image-signing` and remember the previous directory.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
pushd image-signing
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove the state file of an earlier run, if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm -f image-signing-example.json || true
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This example uses the following variables.'
printf '%s\n' ''
printf '%s\n' 'For the native deployment:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native container image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name for this image (default: `sconeapps`)'
printf '%s\n' ''
printf '%s\n' 'For the signing and confidential deployment:'
printf '%s\n' ''
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the SCONE-protected image'
printf '%s\n' '- `$REPO_CREDENTIALS` - Path to Docker credentials file used by the signing push (default: `~/.docker/config.json`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.0.8`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS Kubernetes namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS Kubernetes name (for example, `cas`)'
printf '%s\n' '- `$CAS_ENDPOINT` - Address the manifest targets; keep it in sync with `$CAS_NAME`.`$CAS_NAMESPACE` (default: `cas.default`), or set to an external CAS address to run against one'
printf '%s\n' '- `$TEE_TYPE` - Set to `cvm` for CVM mode or `sgx` for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `true` for confidential nodes, or `false` for Kata Pods'
printf '%s\n' '- `$NAMESPACE` - Kubernetes namespace where the demo runs (default: `ci-scone-td-build`)'
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Load environment variables from the tplenv definition file.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
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
printf '%s\n' 'Generate the job manifest with the selected image and pull-secret values:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render the template with the selected values.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 3. Deploy Key Management Infrastructure'
printf '%s\n' ''
printf '%s\n' 'The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in'
printf '%s\n' 'the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.'
printf '%s\n' ''
printf '%s\n' 'The KBS and key provider run in this demo'\''s own `${NAMESPACE}`, not the shared `trustee`'
printf '%s\n' 'namespace used by a cluster-wide CoCo/Trustee install, so applying and cleaning them up never'
printf '%s\n' 'touches another workload'\''s resources.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render the KBS and key-provider manifests into this demo's namespace.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file k8s/kbs.template.yaml --create-values-file --output k8s/kbs.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file k8s/key-provider.template.yaml --create-values-file --output k8s/key-provider.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Deploy the Key Broker Service.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -f k8s/kbs.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Deploy the key provider.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -f k8s/key-provider.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for KBS to be ready.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=condition=available deployment/kbs -n ${NAMESPACE} --timeout=120s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the key provider to be ready.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=condition=available deployment/keyprovider -n ${NAMESPACE} --timeout=120s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Forward the key provider port to localhost so skopeo can reach it.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Self-restarting loop avoids killing unrelated processes that may already use port 50000.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
while true; do kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000 2>/dev/null; sleep 2; done &
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
export PORT_FORWARD_PID=$!
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Give the port-forward a moment to establish the connection.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
sleep 3
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Generate Signing Keys'
printf '%s\n' ''
printf '%s\n' 'Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed'
printf '%s\n' 'to verify signatures without exposing the private key.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove the key pair of an earlier run, since skopeo refuses to overwrite it.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm -f ./config/image-signing-key.*
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the Ed25519 signing key pair in the format expected by skopeo.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
skopeo generate-sigstore-key --output-prefix ./config/image-signing-key --passphrase-file ./config/empty-passphrase.txt
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Configure the registry to store signatures as sigstore OCI attachments:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Configure sigstore attachments for the registry (user-level, no sudo required).
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Uses a demo-specific file rather than `default.yaml`, since `registries.d` merges
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# every file in the directory; this avoids overwriting any existing registry config.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# The signatures go to the registry that receives the signed image, which is not
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# necessarily ${REGISTRY} (for example after ./scripts/use-registry.sh localhost:30500).
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
SIGNING_REGISTRY="${DESTINATION_IMAGE_NAME%%/*}"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
mkdir -p ~/.config/containers/registries.d
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
cat <<EOF > ~/.config/containers/registries.d/image-signing-demo.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker:
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    ${SIGNING_REGISTRY}:
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
        use-sigstore-attachments: true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
EOF
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Create the Rust project (or reuse an existing one):'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create the Rust project in `hello-world` if it does not already exist.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
cargo new hello-world || echo "hello-world already exists - using existing one"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Build the container image.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker build -t $IMAGE_NAME .
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Push the container image to the registry.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker push $IMAGE_NAME
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Check whether the pull secret already exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
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
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Load environment variables from the tplenv definition file.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Create the Docker registry pull secret.
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
printf '%s\n' '## 7. Run the Native Application'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -f manifest.job.yaml -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the Kubernetes resource to reach the expected state.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Show logs from the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete job image-signing -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the Kubernetes resource to reach the expected state.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Before sending encrypted policies to CAS, attest CAS via the Kubernetes API. The kubectl path'
printf '%s\n' 'covers in-cluster CAS; if it fails (typical when `${CAS_NAME}.${CAS_NAMESPACE}` resolves to an'
printf '%s\n' 'external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Attest the CAS instance before sending encrypted policies.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \
    || scone cas attest ${CAS_NAME}.${CAS_NAMESPACE} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 9. Register and Sign the Confidential Image'
printf '%s\n' ''
printf '%s\n' '`manifests/scone.template.yaml` holds a `Register` document and an `Apply` document. Setting'
printf '%s\n' '`image-signing-key`, `signing-key-passphrase-file` and `registry-auth-file` in the `Register`'
printf '%s\n' 'document activates the encrypted-image flow: `scone-td-build` sconifies the image, then uses'
printf '%s\n' '`skopeo` to encrypt the layers with the attestation-agent key provider, embed a Sigstore'
printf '%s\n' 'signature, and push the result to `${DESTINATION_IMAGE_NAME}`. The `Apply` document then'
printf '%s\n' 'writes `manifest.job.sanitized.yaml` and the CAS policies for the encrypted image.'
printf '%s\n' ''
printf '%s\n' '`${REPO_CREDENTIALS}` defaults to `${HOME}/.docker/config.json` in `Values.yaml`, and `tplenv`'
printf '%s\n' 'exports it as a literal, single-quoted string, so `$HOME` is never expanded by the shell on its'
printf '%s\n' 'own. Expanding it with `eval` would work too, but it treats the whole path as shell code, so a'
printf '%s\n' 'path containing shell metacharacters (parentheses, semicolons, `$(...)`, etc.) either breaks or,'
printf '%s\n' 'worse, gets executed. The substitution below only ever replaces a literal `${HOME}` or `~` prefix'
printf '%s\n' 'with the real value of `$HOME`, so the rest of the path is never interpreted as code:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Expand a literal ${HOME} or ~ prefix in REPO_CREDENTIALS without treating the rest of the
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# path as shell code (a path with parentheses or other shell metacharacters must still work).
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
repo_credentials="${REPO_CREDENTIALS}"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
repo_credentials="${repo_credentials/#\$\{HOME\}/$HOME}"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
repo_credentials="${repo_credentials/#\~/$HOME}"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
export REPO_CREDENTIALS="$repo_credentials"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render from the environment: Values.yaml would bring back the unexpanded REPO_CREDENTIALS.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --values-file /dev/null --file manifests/scone.template.yaml --output manifests/scone.yaml --indent
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Register, sign, and encrypt the confidential image, then generate the sanitized manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
OCICRYPT_KEYPROVIDER_CONFIG=./config/ocicrypt.conf scone-td-build apply -f manifests/scone.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 10. Verify Image Signature'
printf '%s\n' ''
printf '%s\n' '`skopeo inspect` only reports image metadata, it never checks a signature against a key, so on'
printf '%s\n' 'its own it cannot prove the image was actually signed with `./config/image-signing-key.private`'
printf '%s\n' 'from Step 4. `cosign verify` (compatible with `skopeo`'\''s sigstore signatures) does the actual'
printf '%s\n' 'cryptographic check against the matching public key:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Inspect the signed and encrypted image (metadata only, does not verify anything).
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
skopeo inspect docker://${DESTINATION_IMAGE_NAME}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Cryptographically verify the image was signed with our private key. --insecure-ignore-tlog is
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# required because this key pair signs offline and never uploads to the public transparency log.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# A localhost registry (see ./scripts/use-registry.sh) speaks plain HTTP, so cosign must be told to use it.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
COSIGN_REGISTRY_FLAGS=""
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
case "${DESTINATION_IMAGE_NAME%%/*}" in
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  localhost:*|127.0.0.1:*) COSIGN_REGISTRY_FLAGS="--allow-http-registry --allow-insecure-registry" ;;
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
esac
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
cosign verify ${COSIGN_REGISTRY_FLAGS} --key ./config/image-signing-key.pub --insecure-ignore-tlog ${DESTINATION_IMAGE_NAME}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 11. Transform and Deploy the Signed Confidential Application'
printf '%s\n' ''
printf '%s\n' '> **Blocked:** This step requires `ctd-decoder` to be installed on every cluster node and'
printf '%s\n' '> containerd to be configured with the `ocicrypt` stream processor so it can decrypt the encrypted'
printf '%s\n' '> image layers at pull time. Plain k3d clusters do not include this. See'
printf '%s\n' '> [containers/ocicrypt](https://github.com/containers/ocicrypt) for setup instructions.'
printf '%s\n' '>'
printf '%s\n' '> Once the cluster has `ctd-decoder`, deploy the manifest generated in step 9:'
printf '%s\n' '>'
printf '%s\n' '> ```text'
printf '%s\n' '> kubectl apply -f manifest.job.sanitized.yaml -n ${NAMESPACE}'
printf '%s\n' '> kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '> kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf '%s\n' '> ```'
printf '%s\n' ''
printf '%s\n' '## 12. Uninstall `image-signing`'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the key provider port-forward. Kill the restart loop first so it does not respawn,
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# then the kubectl child it spawned -- killing only the wrapper PID leaves that child alive
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# and owning port 50000, which breaks the next run.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill ${PORT_FORWARD_PID} 2>/dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
pkill -f "kubectl port-forward -n ${NAMESPACE} svc/keyprovider 50000:50000" 2>/dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the key provider and the Key Broker Service. These live in this demo's own
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# ${NAMESPACE} and have no Namespace resource of their own, so deleting the rendered
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# manifests removes exactly what the demo created and never the namespace other
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# workloads may share.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -f k8s/key-provider.yaml --ignore-not-found
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -f k8s/kbs.yaml --ignore-not-found
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove the sigstore-attachments config this demo added; it's a separate file in
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# registries.d, so this never touches any other registries.d configuration.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm -f ~/.config/containers/registries.d/image-signing-demo.yaml
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
printf '%s\n' '## Automation'
printf '%s\n' ''
printf '%s\n' 'You can run this workflow with:'
printf '%s\n' ''
printf '%s\n' './scripts/image-signing.sh'
printf '%s\n' ''
printf '%s\n' 'It asks for user input unless you set:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"'
printf '%s\n' ''
printf '%s\n' 'This uses values from `image-signing/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.'
printf '%s\n' ''
printf '%s\n' 'If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/image-signing.sh`.'
printf "%b" "$RESET"

