# Node prerequisites for the NFS-backed shared-volume demo

scone-td-build re-shares a PVC used by more than one pod over NFS: it generates
an NFS-server `Deployment` + `Service`, and rewrites each consumer's volume to a
Kubernetes `nfs:` volume pointing at `<nfs-server>.<namespace>.svc.cluster.local:/`.

For that `nfs:` volume to mount, every node that runs a consumer (or the NFS
server) needs two things that a plain cluster often lacks. These manifests apply
them remotely (no SSH) via a privileged DaemonSet that `nsenter`s into the host.
They are one-shot: apply, wait for the log line, then delete — the change
persists on the host.

## 1. `mount.nfs` on every node (`nfs-common`)

Without `/sbin/mount.nfs` the kubelet fails with
`bad option; you might need a /sbin/mount.<type> helper program`.

```bash
kubectl apply -f 01-install-nfs-common.yaml
# wait until each pod logs "INSTALLED <node>: /usr/sbin/mount.nfs" (or ALREADY_PRESENT)
kubectl -n kube-system logs -l app=install-nfs-common | grep -E 'INSTALLED|ALREADY_PRESENT'
kubectl -n kube-system delete ds install-nfs-common   # package persists
```

## 2. Host resolution of `*.svc.cluster.local` → CoreDNS

The kubelet mounts the NFS volume by the service DNS name, resolved by the
**host** resolver (not the pod's). Cluster DNS is normally only wired for pods,
so the host cannot resolve the NFS service name and the mount fails with
`Resource temporarily unavailable` (really `EAI_AGAIN`). This routes only
`cluster.local` on the host to CoreDNS.

`02-node-cluster-dns.yaml` assumes CoreDNS (`kube-dns`) at `10.96.0.10`. Confirm
with `kubectl -n kube-system get svc kube-dns` and edit the manifest if it differs.

```bash
kubectl apply -f 02-node-cluster-dns.yaml
# wait until each pod resolves the service, e.g. "nfs-server...svc.cluster.local: 10.x.x.x"
kubectl -n kube-system logs -l app=node-cluster-dns | grep -E 'RESOLVED_ON|svc.cluster.local'
kubectl -n kube-system delete ds node-cluster-dns   # resolved config persists
```

Both DaemonSets are privileged and modify the host. They are meant for a
test/CI cluster you control. In production, bake `nfs-common` and node DNS into
the node image / kubelet configuration instead.
