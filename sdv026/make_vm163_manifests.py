#!/usr/bin/env python3
"""Draft SDV-026 VM 163 manifests from verified `vm163` scone-sptd-build bundles.

Temporary SDV-026 harness, not a product tool. NOTHING here is deployable as is:
the container images are the SYNTHETIC prepared-image digests the harness passed to
the compiler (registry.example/sdv026-synthetic/prepared@...), and the envcas
selectors (SCONE_CAS_ADDR / SCONE_CONFIG_ID) are SYNTHETIC. Replace both with the
real prepared images and CAS session ids before applying.

Usage: make_vm163_manifests.py DEMOS_ROOT RUN_TSV BUNDLE_DIR LABEL OUT_DIR

Writes one <case>.yaml per workload whose `vm163` build and verify passed for
LABEL in RUN_TSV: the sanitized workload exactly as compiled, plus the demo's own
Services (namespace rewritten to sdv-demos). NetworkPolicies are left out: they do
not select hostNetwork Pods. ConfigMaps/Secrets the compiled workload consumed are
left out too: the compiler moved them into protected references (CAS), so the
cluster does not need them.
"""
import json, os, sys

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sptd_inputs as h  # noqa: E402

NS = h.VM163["namespace"]


def main():
    demos_root, tsv, bundles, label, out = sys.argv[1:6]
    os.makedirs(out, exist_ok=True)
    cases = {c[0]: c for c in h.CASES + h.OPTIONAL_CASES}
    passed = {}
    for line in open(tsv):
        v, variant, case, wl, res = line.rstrip("\n").split("\t", 4)
        if v == label and variant == "vm163" and res.startswith("PASS"):
            passed.setdefault(case, []).append(wl)
    written = []
    for case in sorted(passed):
        _, path, demo, values, _ = cases[case]
        docs = h.load_docs(demos_root, path, values)
        parts = []
        for wl in passed[case]:
            gen = f"{label}-vm163-{case}-{wl}"
            workload = json.load(open(os.path.join(bundles, gen, "workload.json")))
            receipt = os.path.join(bundles, gen + ".receipt.json")
            parts.append((f"# {workload['kind']}/{wl}: sanitized output of generation {gen}\n"
                          f"# (scone-sptd-build {label}, build + verify --exact PASS; receipt {os.path.basename(receipt)}).\n",
                          workload))
        for d in docs:
            if d["kind"] == "Service":
                d = json.loads(json.dumps(d))
                d["metadata"]["namespace"] = NS
                parts.append((f"# Service/{d['metadata']['name']}: copied from {path}, namespace set to {NS}.\n", d))
        header = (f"# SDV-026 DRAFT for the single-node cluster on VM 163 (node {h.VM163['node']} is a placeholder).\n"
                  f"# Source: {path} ({demo}). NOT DEPLOYABLE AS IS: images are SYNTHETIC prepared-image\n"
                  "# digests under registry.example/sdv026-synthetic, and SCONE_CAS_ADDR/SCONE_CONFIG_ID are\n"
                  "# SYNTHETIC selectors. Replace them with the real prepared images and CAS session ids.\n"
                  "# Pod shape from the harness vm163 variant: hostNetwork, dnsPolicy ClusterFirstWithHostNet,\n"
                  f"# nodeName, not-ready toleration, RuntimeClass {h.VM163['runtime_class']}.\n")
        body = header + "".join("---\n" + c + yaml.safe_dump(d, sort_keys=False) for c, d in parts)
        fname = os.path.join(out, f"{case}.yaml")
        open(fname, "w").write(body)
        written.append(fname)
    # pet-clinic's MariaDB is native by design (mariadb.template.yaml: "runs natively
    # (not confidential)"): pinned public image, same node shape, no SPTD RuntimeClass.
    lock_dir = os.path.join(demos_root, "sdv026")
    images = h.Images(json.load(open(os.path.join(lock_dir, "images.lock.json"))), lock_dir, "derived")
    _, path, demo, values, extra = cases["pet-clinic-db"]
    parts = []
    for d in h.load_docs(demos_root, path, values) + [o for e in extra for o in h.load_docs(demos_root, e, values)]:
        d["metadata"]["namespace"] = NS
        if d["kind"] in h.WORKLOAD_KINDS:
            h.vm163_shape(d)
            pod = h.pod_of(d)
            del pod["runtimeClassName"]
            for c in pod["containers"]:
                c["image"] = images.lookup(c["image"], demo)[0]
        parts.append(d)
    header = (f"# SDV-026 DRAFT for VM 163: pet-clinic's MariaDB, NATIVE (not compiled by scone-sptd-build;\n"
              f"# {path} says it runs natively). Image pinned to the anonymously resolved public digest.\n"
              "# No RuntimeClass. The Secret holds the demo's own non-secret DB values from pet-clinic/Values.yaml;\n"
              "# the confidential petclinic receives the same values through CAS, not through this Secret.\n"
              "# emptyDir keeps the demo's behaviour (data lost with the Pod).\n")
    fname = os.path.join(out, "pet-clinic-db.native.yaml")
    open(fname, "w").write(header + "".join("---\n" + yaml.safe_dump(d, sort_keys=False) for d in parts))
    written.append(fname)
    ns = {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NS}}
    open(os.path.join(out, "00-namespace.yaml"), "w").write("# SDV-026 demo namespace on VM 163.\n" + yaml.safe_dump(ns, sort_keys=False))
    print("\n".join(written))


if __name__ == "__main__":
    main()
