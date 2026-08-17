# SCONE ConfigMap Example: Secure Configuration Data in Kubernetes

This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a SCONE-enabled Rust application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.

[![ConfigMap Example](../../docs/configmap.gif)](../../docs/configmap.mp4)

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

## 3. Set Up Environment Variables

Every file reference below goes through `$DEMO_DIR`, this demo's directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/configmap`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"
# Remove `configmap-example.json` if it exists.
rm -f "$DEMO_DIR/configmap-example.json" || true
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

Load the full variable set from `environment-variables.md`, which also defines the registry credentials used later to create the pull secret:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

values-file

Create the demo namespace if it does not already exist. The fallback echo keeps re-runs idempotent.

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

## 4. Build the Native Rust Image

```bash
# Build the container image.
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
# Push the container image to the registry.
docker push ${NATIVE_IMAGE_NAME}
```

## 5. Render the Manifests

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml" --indent
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
```

Before applying, confirm that image values were substituted correctly.

## 6. Add a Docker Registry Secret

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
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

## 7. Deploy the Native App (Optional)

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-1
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-2

# Clean up native app
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
```

Your containers should print content from the mounted ConfigMap files.

## 8. Prepare and Apply the SCONE Manifest

First, attest the CAS so the local SCONE CLI has the correct session encryption key. The kubectl path covers an in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
  || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
    --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
```

```bash
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
```

This command:

- Generates a SCONE session
- Attaches the session to your manifest
- Produces `$DEMO_DIR/manifests/manifest.prod.sanitized.yaml`

## 9. Deploy the SCONE-Protected App

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
```

## 10. View Logs

```bash
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-1 --follow
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-2 --follow
```

## 11. Clean Up

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
```