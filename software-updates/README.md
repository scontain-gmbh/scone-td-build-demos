# Software Updates for Confidential Python Applications

This example demonstrates how to perform a **software update** of a confidential Python application using SCONE and `scone-td-build`. Two versions of the application are built and deployed:

- **Version 1** — the initial confidential deployment
- **Version 2** — the updated version, deployed via a Kubernetes rolling update

The demo shows that secrets (such as `API_PASSWORD`) are **preserved across the update**, since they live in a Kubernetes Secret that is not touched during the application upgrade.

---

## Project Structure

```
software-updates/
├── print_env1.py                  # Version 1 of the Python application
├── print_env2.py                  # Version 2 of the Python application
├── Dockerfile                     # Builds either version via --build-arg VERSION=1|2
├── requirements.txt               # No external dependencies (stdlib only)
├── scone.v1.template.yaml         # SCONE Register + Apply template for Version 1
├── scone.v2.template.yaml         # SCONE Register + Apply template for Version 2
├── environment-variables.md       # tplenv variable definitions
├── registry.credentials.md        # tplenv registry credential definitions
├── k8s/
│   ├── manifest.v1.template.yaml  # Kubernetes Deployment template for Version 1
│   └── manifest.v2.template.yaml  # Kubernetes Deployment template for Version 2
└── README.md
```

---

## Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX or CVM support
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- `docker` with push access to a registry your cluster can pull from

---

## 1. Set Up the Environment

Assume you start in `scone-td-build-demos` and switch into this demo directory:

```bash
# Enter `software-updates` and remember the previous directory.
pushd software-updates
# Remove generated state files from any previous run.
rm -f software-updates-demo.json scone.v1.yaml scone.v2.yaml manifest.prod.sanitized.yaml manifest.prod.session.yaml || true
```

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

---

## 2. Build and Push the Native Docker Images

The Dockerfile accepts a `VERSION` build argument to choose which Python script to embed. Build both versions:

```bash
# Build the Version 1 container image.
docker build --build-arg VERSION=1 -t ${IMAGE_NAME_V1} .
# Push the Version 1 container image to the registry.
docker push ${IMAGE_NAME_V1}
# Build the Version 2 container image.
docker build --build-arg VERSION=2 -t ${IMAGE_NAME_V2} .
# Push the Version 2 container image to the registry.
docker push ${IMAGE_NAME_V2}
```

---

## 3. Create the Kubernetes Namespace

We try to ensure the namespace exists. This may fail when running in a container already in the target namespace, so we ignore that failure.

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

---

## 4. Add a Docker Registry Secret

A pull secret is needed to pull both the native and confidential container images.

- `$REGISTRY` — the registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` — your registry login name
- `$REGISTRY_TOKEN` — your registry pull token (see [how to create a token](https://sconedocs.github.io/registry/))

```bash
# Check whether the pull secret already exists.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Load environment variables from the tplenv definition file.
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

---

## 5. Create the API Credentials Secret

The `API_USER` and `API_PASSWORD` are injected into the application from a Kubernetes Secret. The secret is created once and **persists across software updates**:

```bash
# Generate a random API password.
API_PASSWORD=$(openssl rand -hex 16)
# Create the Kubernetes secret with the API credentials.
kubectl create secret generic api-credentials \
  --namespace ${NAMESPACE} \
  --from-literal=api-user=myself \
  --from-literal=api-password="${API_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
# Print a status message.
echo "API credentials secret created. Password checksum: $(echo -n "${API_PASSWORD}" | md5sum | cut -d' ' -f1)"
```

Note the printed checksum. After the software update (Part 2 below), the application should print the **same checksum**, confirming the secret was preserved.

---

## 6. Render the Manifests

Render the Kubernetes deployment manifest and SCONE configuration for Version 1:

```bash
# Render the Version 1 deployment manifest.
tplenv --file k8s/manifest.v1.template.yaml --create-values-file --output k8s/manifest.v1.yaml --indent
# Render the Version 1 SCONE configuration.
tplenv --file scone.v1.template.yaml --create-values-file --output scone.v1.yaml --indent
```

---

## Part 1 — Deploy Version 1

### Step 7. Generate the signing key

When protecting binaries for confidential execution, `scone-td-build` signs them with a key stored in `identity.pem`:

```bash
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
```

### Step 8. Build the confidential image and session for Version 1

```bash
# Remove any existing state file.
rm -f software-updates-demo.json || true
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y scone.v1.yaml
```

This command:

- Registers and pushes the Version 1 confidential image (`${DESTINATION_IMAGE_NAME_V1}`)
- Creates a CAS session
- Produces `manifest.prod.sanitized.yaml` referencing the confidential image

### Step 9. Deploy Version 1

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
```

### Step 10. Verify the Version 1 deployment

```bash
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/python-hello-user -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs -n ${NAMESPACE} -l app=python-hello-user --tail=20
```

You should see output such as:

```
Version 1: Hello, 'myself' - thanks for passing along the API_PASSWORD
The checksum of the original API_PASSWORD is '<checksum>'
Version 1: Hello, user 'myself'!
The checksum of the current password is '<checksum>'
Running Version 1. Update by re-applying the v2 confidential manifest.
```

---

## Part 2 — Software Update to Version 2

The API credentials Secret is **not modified** during this update. The same `api-credentials` Kubernetes Secret is mounted into both v1 and v2 pods.

### Step 11. Render the manifests for Version 2

```bash
# Render the Version 2 deployment manifest.
tplenv --file k8s/manifest.v2.template.yaml --create-values-file --output k8s/manifest.v2.yaml --indent
# Render the Version 2 SCONE configuration.
tplenv --file scone.v2.template.yaml --create-values-file --output scone.v2.yaml --indent
```

### Step 12. Build the confidential image and update the session for Version 2

```bash
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y scone.v2.yaml
```

This command:

- Registers and pushes the Version 2 confidential image (`${DESTINATION_IMAGE_NAME_V2}`)
- Updates the existing CAS session (same session name as Version 1)
- Produces `manifest.prod.sanitized.yaml` referencing the Version 2 confidential image

### Step 13. Apply the update

Applying the new manifest triggers a Kubernetes **rolling update** — the v1 pods are replaced by v2 pods without downtime:

```bash
# Apply the updated Kubernetes manifest.
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
# Wait for the rolling update to complete.
kubectl rollout status deployment/python-hello-user -n ${NAMESPACE} --timeout=300s
```

### Step 14. Verify the Version 2 deployment

```bash
# Show logs from the Kubernetes workload.
kubectl logs -n ${NAMESPACE} -l app=python-hello-user --tail=20
```

You should see output such as:

```
Version 2 (updated): Hello, 'myself' - software update successful!
The checksum of the original API_PASSWORD is '<checksum>'
Version 2: Hello, user 'myself'!
The checksum of the current password is '<checksum>'
Running Version 2.
```

The **checksum must match** the one printed by Version 1 and the one printed in Step 5, confirming that `API_PASSWORD` was preserved across the software update.

---

## Cleanup

Remove all deployed resources when you are finished:

```bash
# Delete the Kubernetes deployment.
kubectl delete deployment python-hello-user --namespace ${NAMESPACE} --ignore-not-found
# Wait for the pods to be terminated.
kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=python-hello-user --timeout=300s
# Delete the API credentials secret.
kubectl delete secret api-credentials --namespace ${NAMESPACE} --ignore-not-found
# Return to the previous working directory.
popd
```
