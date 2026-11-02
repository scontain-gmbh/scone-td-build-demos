# Encrypted Volume Demo with memos

## Introduction

[memos](https://github.com/usememos/memos) is an open-source note-taking service. It keeps everything, accounts and notes, in a SQLite database under `/var/opt/memos`, which this demo puts on a `PersistentVolumeClaim`.

Anyone who can read that storage can read the notes: a node administrator, a backup, a snapshot of the cloud disk. This demo shows how `scone-td-build` closes that gap without changing memos or the manifest:

- The claim stays mounted, and `scone-td-build` binds a SCONE volume to the same path in the CAS session. The SCONE runtime encrypts and authenticates every file memos writes there.
- CAS generates the key the first time the volume is used and hands it only to the attested memos enclave. Nobody else sees it, not even the cluster administrator.
- A pod without SCONE that mounts the same claim finds only ciphertext.
- CAS also records the latest state of the volume, so the enclave refuses an older copy of the files or an emptied claim.

You first run memos natively and read a note straight off the disk, then run the confidential version and try again.

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX resources, a running LAS, and a default `StorageClass`
- The Kubernetes command-line tool (`kubectl`), `docker`, `curl`, `jq` and `openssl`
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

## 3. Set Up Environment Variables

Assume you start in `scone-td-build-demos`, then switch to this demo:

```bash
# Enter `memos` and remember the previous directory.
pushd memos
# Remove `storage.json` if it exists.
rm storage.json || true
```

Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:

- `$IMAGE_NAME` - Name of the native `memos` image
- `$DESTINATION_IMAGE_NAME` - Name of the confidential image
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)
- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.0.8`)
- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)
- `$CAS_NAME` - CAS name (for example, `cas`)
- `$CAS_ENDPOINT` - Address the manifest targets; keep it in sync with `$CAS_NAME`.`$CAS_NAMESPACE` (default: `cas.default`), or set to an external CAS address to run against one
- `$TEE_TYPE` - Set to `cvm` for CVM mode or `sgx` for SGX
- `$SCONE_ENCLAVE` - In CVM mode, set to `true` for confidential nodes, or `false` for Kata Pods
- `$NAMESPACE` - Kubernetes namespace where the demo runs, and CAS namespace of its sessions (default: `memos-demo`)
- `$ENCLAVE_HEAP` - Enclave heap of the memos container (default and minimum: `2G`)

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

The demo account gets a new random password on every run:

```bash
# Generate the password of the memos demo account.
export MEMOS_PASSWORD="$(openssl rand -hex 16)"
# The port-forward below makes memos reachable here.
export MEMOS_URL="http://localhost:5230"
```

Create the demo namespace if it does not already exist:

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${CAS_ENDPOINT}` points at an external CAS like `edge.scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \
    || scone cas attest ${CAS_ENDPOINT} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any \
    || echo "CAS attestation skipped: ${CAS_ENDPOINT} runs in simulation mode, so it cannot produce a DCAP quote"
```

Render the templates:

```bash
# Render the Kubernetes manifest of memos.
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml
# Render the pod that reads the claim without SCONE.
tplenv --file disk-reader.template.yaml --create-values-file --output disk-reader.yaml
# Render the SCONE manifest that drives register plus apply.
tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent
```

## 4. Create a Pull Secret

If the pull secret does not exist yet, create it using registry credentials.

- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` - Registry login name
- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

## 5. Build the Image

The `Dockerfile` builds memos from its release tag. The upstream image links memos statically, and a static binary cannot be sconified, so the backend is built with the SCONE Go toolchain instead.

```bash
# Build the container image.
docker build -t ${IMAGE_NAME} .
# Push the container image to the registry.
docker push ${IMAGE_NAME}
```

Generate a signing key for confidential binaries if needed:

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

## 6. See the Problem: memos Without SCONE

Clean up previous runs first:

```bash
# Delete the Kubernetes resources if they exist.
kubectl delete -f manifest.yaml -n ${NAMESPACE} --ignore-not-found
kubectl delete pod disk-reader -n ${NAMESPACE} --ignore-not-found
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=memos -n ${NAMESPACE} --timeout=240s || echo "ok - no memos deployment yet"
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true
```

Start the native memos and write a note:

```bash
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
```

Stop memos, so that SQLite writes everything into its database file, and read the claim from a pod that knows nothing about memos:

```bash
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
```

The first bytes read `SQLite format 3`, and the note is right there in the file.

Remove the native deployment and its claim:

```bash
# Delete the Kubernetes resources.
kubectl delete pod disk-reader -n ${NAMESPACE}
kubectl delete -f manifest.yaml -n ${NAMESPACE}
# Wait for the claim to be gone, so the confidential run starts on a new one.
kubectl wait --for=delete pvc/memos-data -n ${NAMESPACE} --timeout=240s || true
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true
```

## 7. Convert the Manifest

```bash
# Register the image and transform the manifest in one step.
scone-td-build apply -f scone.yaml
```

`scone-td-build` reports that the claim becomes an encrypted volume:

```
PersistentVolumeClaim memos-data mounted by deployment/memos at /var/opt/memos becomes an encrypted SCONE volume. CAS holds its key in session memos-demo/volume-memos-data.
deployment/memos mounts an encrypted volume, so it uses strategy Recreate: a rolling update would open the volume from two pods at once.
```

In `manifest.sanitized.yaml` the claim is still mounted at `/var/opt/memos`, and the Deployment uses `strategy: Recreate`. In `manifest.session.yaml`:

- `memos-demo/volume-memos-data` owns the volume and its key, and exports the volume to the memos session.
- The memos session imports it and binds it at `/var/opt/memos` in the memos image.

The key belongs to the claim, not to the Deployment. It stays in CAS when you change the manifest and apply again, as long as `metadata.namespace` in `scone.yaml` stays the same.

## 8. Deploy the Confidential Manifest

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifest.sanitized.yaml -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s
# Start a self-restarting port-forward; the loop recreates it if the pod bounces during attestation.
set -m
while true; do kubectl port-forward deployment/memos 5230:5230 -n ${NAMESPACE} 2>/dev/null; sleep 2; done & echo $! > /tmp/pf-5230.pid
set +m
```

## 9. Use memos

memos looks and behaves the same. Create the account and the note again:

```bash
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- ./memos-api.sh signup
# Write the note this demo protects.
./memos-api.sh post "The safe code is 4711"
# Read it back.
./memos-api.sh find "safe code"
```

You can also open <http://localhost:5230> in a browser and sign in as `demo` with the password in `$MEMOS_PASSWORD`.

## 10. Restart the Pod

The note survives a new pod: the new enclave attests, gets the same key from CAS, and opens the same files.

```bash
# Delete the pod; the Deployment starts a new one.
kubectl delete pod -l app=memos -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- ./memos-api.sh find "safe code"
```

## 11. Look at the Disk

Stop memos and run the same reader as before:

```bash
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
```

This time the database starts with random bytes instead of `SQLite format 3`, the note is nowhere in the files, and next to the database there is a `volume.fspf` file: the encrypted metadata the SCONE runtime keeps for the volume.

Start memos again, and the note is back:

```bash
# Start memos.
kubectl scale deployment memos --replicas=1 -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app=memos -n ${NAMESPACE} --timeout=600s
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- ./memos-api.sh find "safe code"
```

## 12. Uninstall the Demo

```bash
# Delete the Kubernetes resources, the claim included.
kubectl delete -f manifest.sanitized.yaml -n ${NAMESPACE}
# Stop the previous background process (and its current port-forward child) if still running.
kill -- -"$(cat /tmp/pf-5230.pid)" 2>/dev/null || true
# Remove `/tmp/pf-5230.pid` if it exists.
rm -f /tmp/pf-5230.pid
# Return to the previous working directory.
popd
```

CAS keeps the volume's sessions in the CAS namespace `${NAMESPACE}`, and with them the record of the volume's latest state. A new, empty claim under the same namespace is refused with `The FSPF tag is not fresh - suspected replay attack`, which is the rollback protection at work. To install the demo again from scratch, pick a new `NAMESPACE`.

## What You Can Change

These annotations on the `PersistentVolumeClaim` change how it is protected:

| Annotation | Effect |
|---|---|
| `scone.cloud/encrypted-volume: "false"` | The claim is mounted unencrypted, as the manifest declares it. |
| `scone.cloud/rollback-protection: "false"` | The enclave accepts an older copy of the volume, or an empty one, for claims restored from snapshots. |
| `scone.cloud/volume-generation: "<n>"` | Starts over with a new, empty volume and a new key. The old data cannot be read again. |

An encrypted volume has a single writer: keep `replicas: 1`. See [Encrypted volumes](https://github.com/scontain/scone-td-build/blob/main/docs/public/apply-manifest.md#encrypted-volumes) for the details.
