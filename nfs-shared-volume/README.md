# NFS-backed shared volume demo

This demo shows `scone-td-build`'s automatic NFS sharing (issue #267): when one
volume is used by more than one pod, the tool re-shares it over NFS instead of
mounting it directly into each pod.

The app (`app.py`) is a single image that runs in two roles:

- **writer** appends a timestamped line to `/data/shared.log` every few seconds.
- **reader** reads `/data/shared.log` every few seconds and prints what it sees.

`k8s/manifest.yaml` deploys both as separate Deployments, each mounting the same
`shared-data` PVC at `/data`. Because that PVC is shared by two workloads,
`scone-td-build` automatically:

1. generates a native NFS server that mounts the PVC and re-exports it over NFSv4,
2. rewrites each consumer's `data` volume to mount that NFS export instead of the
   PVC directly.

The result: the reader sees exactly what the writer wrote, through the shared
NFS export.

## Prerequisites

- A cluster with the SCONE stack (operator + LAS + CAS). CAS reachable at
  `cas.default`.
- Docker with push access to `registry.scontain.com/amand1o`.
- A `scone-td-build` binary with NFS shared-volume support.

Adjust `Values.yaml` for your registry, namespace, and CAS if needed.

## Run

```bash
cd nfs-shared-volume

# 1. Build and push the app image.
docker build -t "$IMAGE_NAME" .
docker push "$IMAGE_NAME"

# 2. Namespace + registry pull secret.
kubectl create namespace nfs-demo --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry sconeapps \
  --docker-server=registry.scontain.com \
  --docker-username="$REGISTRY_USERNAME" \
  --docker-password="$REGISTRY_ACCESS_TOKEN" \
  --docker-email="$REGISTRY_EMAIL" \
  -n nfs-demo --dry-run=client -o yaml | kubectl apply -f -

# 3. Render the templates from Values.yaml.
tplenv --file scone.template.yaml        --create-values-file --output scone.yaml --indent
tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml --indent

# 4. Sconify + transform (detects the shared PVC and wires in NFS).
scone-td-build from -y scone.yaml

# 5. Deploy the transformed manifest.
kubectl apply -f manifest.sanitized.yaml
```

## Observe

```bash
kubectl logs -n nfs-demo deploy/file-writer -f    # writing lines
kubectl logs -n nfs-demo deploy/file-reader -f    # reading the same lines
```

The reader's line count climbs and its "last" line matches what the writer just
wrote, confirming both pods share the same file over the generated NFS export.
