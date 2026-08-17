# Web Server Demo

## Introduction

This Rust application is a minimal web service built with [Axum](https://github.com/tokio-rs/axum). It is intentionally small and easy to follow.

[![Web-Server Example](../docs/web-server.gif)](../docs/web-server.mp4)

## Endpoints

- **Generate password (`/gen`)**
  - Generates a random alphanumeric password.
  - Example response:

  ```json
  {
    "password": "aBcD1234EeFgH5678"
  }
  ```

- **Print path (`/path`)**
  - Reads files from `/config` and returns file names and contents.
  - Example response:

  ```json
  {
    "name": "file1.txt",
    "content": "This is the content of file1.txt.\n..."
  }
  ```

- **Print environment variable (`/env/:env`)**
  - Returns the value of the requested environment variable.
  - Example response:

  ```json
  {
    "value": "your_env_value_here"
  }
  ```

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

## 3. Set Up Environment Variables

Every file reference below goes through `$DEMO_DIR`, this demo's directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/web-server`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"

# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/storage.json" || true
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
```

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Create the demo namespace if it does not already exist:

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
```

If attestation fails, review the output for detected issues and suggested tolerance flags.

Render the manifest template:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"
```

## 4. Create a Pull Secret

If the pull secret does not exist yet, create it using registry credentials.

```bash
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

## 5. Build and Register the Image

Build and push the native image:

```bash
# Build the container image.
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
# Push the container image to the registry.
docker push ${NATIVE_IMAGE_NAME}
```

Generate a signing key for confidential binaries if needed:

```bash
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
```

Generate the SCONE config from its template, then run `scone-td-build` to produce the confidential image and sanitized manifest:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
```

If you want to inspect registration details, see [register-image](https://github.com/scontain/k8s-scone/blob/main/register-image.md).

## 6. Test the Native Manifest (Optional)

Clean up previous runs first:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete deployment web-server -n ${NAMESPACE} || echo "ok - no web-server deployment yet"
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server -n ${NAMESPACE} --timeout=240s || echo "ok - no web-server deployment yet"
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
```

Deploy and test:

```bash
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
```

## 7. Deploy the Confidential Manifest

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
```

For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.

## 8. Run the Demo

```bash
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
```

Send test requests:

```bash
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/gen
# Run the demo test script.
"$DEMO_DIR/test.sh"
```

## 9. Uninstall the Demo

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-8000.pid)" 2>/dev/null || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid
```

This demo provides a simple but functional Rust web service that you can extend as needed.
