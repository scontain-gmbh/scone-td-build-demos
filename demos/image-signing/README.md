# SCONE: Image Signing

This example shows how to sign and encrypt a confidential container image using a Sigstore private key, then verify the signature before deploying it to Kubernetes.

Image signing provides supply chain integrity: only images signed with a trusted private key pass verification. Combined with SCONE encryption, the image layers are also protected at rest in the registry.

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX or CVM support
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- `skopeo` for image inspection and signing
- [`cosign`](https://docs.sigstore.dev/cosign/system_config/installation/) to cryptographically verify the image signature
- `openssl` for signing key generation

Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:

- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)
- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)

## 2. Set Up Environment Variables

Resolve the directory this demo lives in, so every file reference below works regardless of the caller's current working directory, and clean up state left over from a previous run:

```bash
# Resolve this demo's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEMO_DIR="$SCRIPT_DIR/../../demos/image-signing/"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/storage.json" || true
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
```

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --eval-export-values --output /dev/null)
```

Create the demo namespace if it does not already exist:

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

## 3. Add a Docker Registry Secret

If you need a pull secret for native and confidential images, create it when missing:

```bash
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
```

## 4. Deploy Key Management Infrastructure

The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.

The KBS and key provider run in this demo's own `${NAMESPACE}`, not the shared `trustee` namespace used by a cluster-wide CoCo/Trustee install, so applying and cleaning them up never touches another workload's resources.

```bash
# Render the KBS and key-provider manifests into this demo's namespace.
tplenv --file "$DEMO_DIR/manifests/kbs.template.yaml" --create-values-file --output "$DEMO_DIR/manifests/kbs.yaml"
tplenv --file "$DEMO_DIR/manifests/key-provider.template.yaml" --create-values-file --output "$DEMO_DIR/manifests/key-provider.yaml"
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
```

## 5. Generate Signing Keys

Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed to verify signatures without exposing the private key.

```bash
# Generate the Ed25519 signing key pair in the format expected by skopeo.
skopeo generate-sigstore-key --output-prefix "$DEMO_DIR/app/config/image-signing-key" --passphrase-file "$DEMO_DIR/app/config/empty-passphrase.txt"
```

Configure the registry to store signatures as sigstore OCI attachments:

```bash
# Configure sigstore attachments for the registry (user-level, no sudo required).
# Uses a demo-specific file rather than `default.yaml`, since `registries.d` merges
# every file in the directory; this avoids overwriting any existing registry config.
mkdir -p ~/.config/containers/registries.d
cat <<EOF > ~/.config/containers/registries.d/image-signing-demo.yaml
docker:
    ${REGISTRY}:
        use-sigstore-attachments: true
EOF
```

## 6. Build the Native Container Image

Build and push the image:

```bash
# Build the container image.
docker build -t $NATIVE_IMAGE_NAME "$DEMO_DIR/app"
# Push the container image to the registry.
docker push $NATIVE_IMAGE_NAME
```

## 7. Run the Native Application

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}
```

Wait for completion and stream logs:

```bash
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
```

Clean up:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
```

## 8. Attest SCONE CAS

Before sending encrypted policies to CAS, attest CAS via the Kubernetes API. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
```

If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.

## 9. Build the Confidential Image and Manifest

Expand a literal `${HOME}` or `~` prefix in `REPO_CREDENTIALS` so the signing step receives an absolute path:

```bash
# Expand a literal ${HOME} or ~ prefix in REPO_CREDENTIALS without treating the rest of the
# path as shell code (a path with parentheses or other shell metacharacters must still work).
repo_credentials="${REPO_CREDENTIALS}"
repo_credentials="${repo_credentials/#\$\{HOME\}/$HOME}"
repo_credentials="${repo_credentials/#\~/$HOME}"
export REPO_CREDENTIALS="$repo_credentials"
```

Render the SCONE manifest template, then run `scone-td-build from` to register, sign, encrypt, and apply in one step:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
OCICRYPT_KEYPROVIDER_CONFIG="$DEMO_DIR/app/config/ocicrypt.conf" \
  scone-td-build from -y "$DEMO_DIR/manifests/scone.yaml"
```

## 10. Verify Image Signature

`skopeo inspect` only reports image metadata; it never checks a signature against a key. `cosign verify` (compatible with `skopeo`'s sigstore signatures) does the actual cryptographic check against the matching public key:

```bash
# Inspect the signed and encrypted image (metadata only, does not verify anything).
skopeo inspect docker://${DESTINATION_IMAGE_NAME}
# Cryptographically verify the image was signed with our private key. --insecure-ignore-tlog is
# required because this key pair signs offline and never uploads to the public transparency log.
cosign verify --key "$DEMO_DIR/app/config/image-signing-key.pub" --insecure-ignore-tlog ${DESTINATION_IMAGE_NAME}
```

## 11. Deploy the Signed Confidential Application

> **Blocked:** This step requires `ctd-decoder` to be installed on every cluster node and containerd to be configured with the `ocicrypt` stream processor so it can decrypt the encrypted image layers at pull time. Plain k3d clusters do not include this. See [containers/ocicrypt](https://github.com/containers/ocicrypt) for setup instructions.
>
> Once the cluster has `ctd-decoder`, deploy the sanitized manifest:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.sanitized.yaml" -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
```

## 12. Clean Up

```bash
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
```