# SCONE: NFS-backed shared volume

This example shows `scone-td-build`'s automatic NFS sharing (issue #267): when a
single volume is used by more than one pod, the tool re-shares it over NFS
instead of mounting it directly into each pod.

The app (`app.py`) is a single image that runs in two roles, selected by `ROLE`:

- **writer** appends a timestamped line to `/data/shared.log` every few seconds.
- **reader** reads `/data/shared.log` every few seconds and prints what it sees.

`manifest.template.yaml` deploys both as separate Deployments, each mounting the
same `shared-data` PVC at `/data`. Because that PVC is shared by two workloads,
`scone-td-build` automatically:

1. generates a native NFS server that mounts the PVC and re-exports it over NFSv4, and
2. rewrites each consumer's `data` volume to mount that NFS export instead of the PVC directly.

The result: the reader sees exactly what the writer wrote, through the shared NFS export.

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX or CVM support and the SCONE stack (operator + LAS + CAS)
- The Kubernetes command-line tool (`kubectl`) and the `kubectl scone` plugin
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- A `scone-td-build` binary with NFS shared-volume support

Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools.

### Node prerequisites (specific to this demo)

Unlike the other demos, the NFS re-sharing needs two things on every node that
runs a consumer or the NFS server: the `mount.nfs` helper (`nfs-common`) and host
resolution of the NFS service DNS name. These are node-level, not something the
manifest or `Values.yaml` can set, so they are a one-time cluster prerequisite.

The step below applies them. It is one-shot and idempotent: each DaemonSet
`nsenter`s into the host, makes the change if it is missing, and is deleted right
after; the change itself persists on the node. See
[`node-prep/README.md`](node-prep/README.md) for what each one does, and set
`SKIP_NODE_PREP=1` if your cluster is already prepared or you lack the rights to
touch `kube-system`.

```bash
if [ "${SKIP_NODE_PREP:-0}" != "1" ]; then
  kubectl apply -f nfs-shared-volume/node-prep/01-install-nfs-common.yaml
  kubectl apply -f nfs-shared-volume/node-prep/02-node-cluster-dns.yaml
  kubectl -n kube-system rollout status ds/install-nfs-common --timeout=180s
  kubectl -n kube-system rollout status ds/node-cluster-dns --timeout=180s
  # The nodes keep the package and the resolver entry once the pods have run.
  kubectl -n kube-system delete ds install-nfs-common node-cluster-dns
fi
```

## 2. Set Up Environment Variables

We assume you start in `scone-td-build-demos`:

```bash
# Enter `nfs-shared-volume` and remember the previous directory.
pushd nfs-shared-volume
```

Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

## 3. Render the Manifests

Render the native manifest and the scone-td-build spec with the selected values:

```bash
# Render the Kubernetes manifest (two Deployments sharing one PVC).
tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
# Render the scone-td-build Register + Apply spec.
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml --indent
```

## 4. Build the Native Container Image

Build and push the writer/reader image:

```bash
# Build the container image.
docker build -t "$IMAGE_NAME" .
# Push the container image to the registry.
docker push "$IMAGE_NAME"
```

## 5. Create a Pull Secret

If the pull secret does not exist yet, create it using registry credentials.

- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` - Registry login name
- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
# Create the pull secret only when it does not already exist, so reruns with a
# precreated secret do not require registry credentials.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Load registry credentials.
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server="$REGISTRY" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
fi
```

## 6. Register the Image and Transform the Manifest

`scone-td-build apply` runs the Register plus Apply flow from a single spec: it
registers/sconifies the image, detects the shared PVC, wires in the NFS server,
and writes the transformed manifest and the CAS policies.

```bash
# Register the image and transform the manifest in one step.
scone-td-build apply -f manifests/scone.yaml
```

This demo uses a **signed** CAS policy (`encrypted-cas-policy: false` in
`scone.template.yaml`), so this step does not attest or encrypt against the CAS
and needs no SGX on the machine running it. See "How the security posture is
set" below.

## 7. Deploy the Confidential Manifest

The transformed manifest (`manifests/manifest.sanitized.yaml`) contains the
sconified writer/reader Deployments, the generated NFS server Deployment and
Service, and the signed CAS policies.

```bash
# Apply the transformed manifest and the CAS policies.
kubectl apply -f manifests/manifest.sanitized.yaml -n ${NAMESPACE}
# Wait for the workloads to become available.
kubectl rollout status deploy/nfs-shared-data -n ${NAMESPACE} --timeout=300s
kubectl rollout status deploy/file-writer -n ${NAMESPACE} --timeout=300s
kubectl rollout status deploy/file-reader -n ${NAMESPACE} --timeout=300s
```

## 8. Observe the Shared Volume

The reader's line count should climb and its "last" line should match what the
writer just wrote, confirming both pods share the same file over the generated
NFS export.

The first write does not happen immediately. A freshly started NFSv4 server
holds a **grace period** of about 90 seconds, during which it refuses the
state-establishing opens that a write needs, so the writer's first `open()`
blocks until that period ends. Reads are not affected, which is why the reader
reports `shared file not created by the writer yet` in the meantime. Wait for
the reader to actually see the file instead of sleeping for a fixed time:

```bash
# Wait until the reader sees the shared file. The generous budget covers the
# NFSv4 grace period (~90s) on the freshly started server.
deadline=$(( $(date +%s) + 240 ))
until kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=20 2>/dev/null | grep -q 'line(s) so far'; do
  if [ "$(date +%s)" -ge "${deadline}" ]; then
    echo "The reader never saw the shared file through the NFS export" >&2
    kubectl logs -n ${NAMESPACE} deploy/file-writer --tail=20 >&2 || true
    kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=20 >&2 || true
    exit 1
  fi
  sleep 5
done
# The writer appends timestamped lines.
kubectl logs -n ${NAMESPACE} deploy/file-writer --tail=5
# The reader sees the same lines through the NFS export.
kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=5
# Prove it is one shared file and not two local ones: the reader's most recent
# line must be a line the writer actually wrote.
last_seen=$(kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=1 | sed -n 's/.*last: //p')
if [ -z "${last_seen}" ]; then
  echo "Could not read the reader's most recent line" >&2
  exit 1
fi
if ! kubectl logs -n ${NAMESPACE} deploy/file-writer --tail=50 | grep -qF "${last_seen}"; then
  echo "The reader's most recent line does not match anything the writer wrote" >&2
  exit 1
fi
echo "The reader sees exactly what the writer wrote, through the NFS export"
```

## 9. Uninstall

```bash
# Delete the workloads, the shared PVC, and the CAS policies.
kubectl delete -f manifests/manifest.sanitized.yaml -n ${NAMESPACE} --ignore-not-found
# Return to the previous working directory.
popd
```

## Automation

You can run this workflow with:

```
./scripts/nfs-shared-volume.sh
```

It asks for user input unless you set:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
```

This uses values from `nfs-shared-volume/Values.yaml` and skips interactive prompts.

If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/nfs-shared-volume.sh`.

## How the security posture is set

`scone-td-build` talks to the CAS through the `scone` CLI, which runs as a SCONE
enclave. Two independent knobs decide how much SGX the setup step needs:

- **Policy protection** (`encrypted-cas-policy` in the Apply block). `false`
  (this demo) produces a *signed* policy: no CAS attestation, no encryption, only
  a local `scone session sign`, which does not require SGX2 on the setup host.
  `true` produces an *encrypted* policy: it attests the CAS and encrypts the
  session to the CAS's attested key inside the enclave, so the setup host needs
  SGX. Use `true` when the setup runs on an untrusted host and the policy carries
  secrets that must never appear in clear.
- **Enclave mode** (`SCONE_PRODUCTION`, `SCONE_MODE`). Controls debug/simulation
  versus production enclaves. It is orthogonal to the policy choice above.

Either way, only the cluster nodes that run the transformed manifest need SGX;
the workloads attest to the CAS at runtime there.
