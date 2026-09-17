# Network Policy

This guide explains how to build, deploy, and test the **Network Policy demo** with `scone-td-build`. You will build client and server images, generate SCONE-protected images, apply Kubernetes manifests, and verify the result.

[![Network Policy Example](../../docs/network-policy.gif)](../../docs/network-policy.mp4)

## 1. Prerequisites

Make sure you have:

- Docker
- A Kubernetes cluster with `kubectl` configured
- `tplenv`
- `scone-td-build` built locally
- Access to a container registry where you can push images

## 2. Build Images

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Every file reference below goes through `$DEMO_DIR`, this demo's directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/network-policy`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"

# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json" || true
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist, then initialize environment variables from `environment-variables.md` using `tplenv`:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Create the demo namespace if it does not already exist:

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

Build and push native images:

```bash
# Build the container image.
docker build -t $SERVER_IMAGE "$DEMO_DIR/app/server/"
# Build the container image.
docker build -t $CLIENT_IMAGE "$DEMO_DIR/app/client/"

# Push the container image to the registry.
docker push $SERVER_IMAGE
# Push the container image to the registry.
docker push $CLIENT_IMAGE
```

## 3. Generate SCONE Images

Create SCONE config files from templates, then run `scone-td-build`:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --output "$DEMO_DIR/manifests/manifest.yaml"
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
```

Push the generated SCONE images:

```bash
# Push the container image to the registry.
docker push $SERVER_IMAGE-scone
# Push the container image to the registry.
docker push $CLIENT_IMAGE-scone
```

## 4. Apply Kubernetes Manifests

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
```

Wait until all pods are running before continuing.

## 5. Test the Setup

Wait for pods and port-forward the server service:

```bash
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="server" -n ${NAMESPACE} --timeout=300s
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="client" -n ${NAMESPACE} --timeout=300s
# A ready pod does not always mean the port is immediately available.
# Wait briefly for the service to become reachable.
sleep 10

# Start a local port-forward to the Kubernetes workload.
kubectl port-forward svc/barad-dur 3000 -n ${NAMESPACE} & echo $! > /tmp/pf-3000.pid
```

Send requests:

```bash
# Send a test request to the demo service endpoint.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
# Send a test request to the demo service endpoint.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
```

Expected result: a random 7-character password, which confirms:

- The application is running correctly
- SCONE-protected images are working
- Network Policy rules allow the intended traffic

## 6. Uninstall the Demo

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-3000.pid) || true
# Remove `/tmp/pf-3000.pid` if it exists.
rm /tmp/pf-3000.pid
```
