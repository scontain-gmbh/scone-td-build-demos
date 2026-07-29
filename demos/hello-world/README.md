# SCONE: Hello World

[![Hello World Example](../docs/hello-world.gif)](../docs/hello-world.mp4)

This example shows how to build a simple cloud-native `hello-world` application in Rust, run it natively in Kubernetes, and then deploy a confidential version with SCONE.

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX or CVM support
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:

- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)
- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)

## 2. Set Up Environment Variables

Resolve the directory this demo lives in, so every file reference below works regardless of the caller's current working directory, and clean up state left over from a previous run:

```bash
# Resolve this demo's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEMO_DIR="$SCRIPT_DIR/../../demos/hello-world/"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json"
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
```

Load the full variable set with `tplenv`, which also defines the registry credentials used later to create the pull secret:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -n ${NAMESPACE} -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

Generate the job manifest with the selected image and pull-secret values:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.job.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.job.yaml"
```

## 3. Build the Native Container Image


Build and push the image:

```bash
# Build the container image.
docker build -t $NATIVE_IMAGE_NAME "$DEMO_DIR/app"
# Push the container image to the registry.
docker push $NATIVE_IMAGE_NAME
```

## 4. Create a Pull Secret

If the pull secret does not exist yet, create it using the registry credentials loaded in step 2.

```bash
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
```

## 5. Run the Native Hello-World Application

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}
```

Wait for completion and stream logs:

```bash
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
```

Clean up:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s
```

## 6. Attest SCONE CAS

Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
```

If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.

## 7. Build the Confidential Image and Manifest

Render the SCONE manifest, which contains everything needed to register the confidential image and transform the Kubernetes manifest in one step:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y "$DEMO_DIR/manifests/scone.yaml"
```

This command registers the confidential image, creates the SCONE session, and produces `$DEMO_DIR/manifests/manifest.prod.sanitized.yaml` from `manifest.job.yaml`.

## 8. Deploy the Confidential Manifest

```bash
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
```

## 9. Uninstall `hello-world`

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s
```

## Automation

You can run this workflow with:

```
./scripts/hello-world.sh
```

It asks for user input unless you set:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
```

This uses values from `hello-world/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.

If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.