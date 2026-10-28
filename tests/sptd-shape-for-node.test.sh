#!/usr/bin/env bash
# td-build-sptd.py shape_for_node must give every scone-dev Pod the node network, PID and IPC namespaces: the scone-dev
# handler refuses CreateContainer otherwise ("unsupported scone-dev security projection: namespaces";
# sptd-hello-container-dev containerd internal/cri/server/container_create_scone_linux.go isHostNamespaceOptions).
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -I - "$repo_root/scripts/sptd/td-build-sptd.py" <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("tdb", sys.argv[1]); tdb = importlib.util.module_from_spec(spec); spec.loader.exec_module(tdb)
for kind, doc in (("Pod", {"kind": "Pod", "metadata": {"name": "p"}, "spec": {"containers": [{"name": "c", "image": "i"}]}}),
                  ("Job", {"kind": "Job", "metadata": {"name": "j"}, "spec": {"template": {"spec": {"containers": [{"name": "c", "image": "i"}]}}}})):
    os.environ.pop("SPTD_HOST_NETWORK", None); os.environ.pop("SPTD_NODE_NAME", None)
    tdb.shape_for_node(doc)
    pod = tdb.pod_spec(doc)
    assert pod["runtimeClassName"] == "scone-dev", (kind, pod)
    assert pod["hostNetwork"] is True and pod["hostPID"] is True and pod["hostIPC"] is True, (kind, pod)
    assert pod["dnsPolicy"] == "ClusterFirstWithHostNet", (kind, pod)
print("shape_for_node: node network, PID and IPC namespaces set for Pod and Job")
PY
