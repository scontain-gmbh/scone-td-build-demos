#!/usr/bin/env python3
"""Generate scone-sptd-build offline inputs (one input root per workload) for SDV-026.

Temporary SDV-026 harness, not a product tool. It reads the demo manifests of this
branch (digest-pinned copies, or templates rendered with the demo's Values.yaml)
plus sdv026/images.lock.json and writes, for every workload document, an input root
accepted by `scone-sptd-build build`:

    <out>/<variant>/<case>/<workload>/{workload.json, plan.json, snapshots/, oci/}

Variants:
  standin          image = base-image digest (real registry object) + its real config
  derived          image = SYNTHETIC digest under synthetic.invalid/<name> + SYNTHETIC
                   config (base config with the Dockerfile's ENTRYPOINT/CMD/... applied)
  probe            PROBE ONLY, never a deployable input: like derived, but every image
                   config (including real public ones) has the execution controls
                   Volumes/ArgsEscaped removed and a python argv[0] renamed, so the
                   compiler reports the next workload-level blocker. All probe images
                   get SYNTHETIC digests.
  vm163            like derived, reshaped for the single-node SDV-026 cluster on VM 163:
                   namespace sdv-demos (workload and every snapshot), hostNetwork,
                   dnsPolicy ClusterFirstWithHostNet, nodeName sptd-k8s-163 (placeholder),
                   a node.kubernetes.io/not-ready toleration and RuntimeClass
                   scone-process-td. Its bundles are the source of sdv026/vm163/.

Public image references in templates (redis:7-bookworm, mariadb:11.4, ...) are pinned
to the digests in images.lock.json (resolved anonymously). Natives
(registry.scontain.com, HTTP 403 anonymously) are replaced per variant as above.

Everything not taken from the demo manifests is synthetic and labelled so:
snapshot uids/resourceVersions, bootstrap selectors, prepared-image digests,
protected object ids, and Secret snapshots for objects the demos create outside
their manifests (placeholder bytes, no key material): flask-redis TLS Secrets
(README, openssl) and the software-updates api-credentials (a SconeSecret that
lives in CAS, not in Kubernetes). A ConfigMap/Secret without metadata.namespace
that a namespaced workload references is snapshotted with the workload's namespace
(what `kubectl apply -n` stores); the index records it as namespace_normalized.

Usage: make_sptd_inputs.py DEMOS_ROOT OUT_DIR VARIANT
"""
import base64, copy, hashlib, json, os, re, sys

import yaml

SUBST = {"${IMAGE_PULL_SECRET_NAME}": "sconeapps", "${NAMESPACE}": "scone-tools"}
# (case, manifest, demo, Values.yaml or None, extra object files)
CASES = [
    ("hello-world", "hello-world/manifest.job.pinned.yaml", "hello-world", None, []),
    ("go-args-env-file", "go-args-env-file/manifests/manifest.pinned.yaml", "go-args-env-file", None, []),
    ("go-args-env-file-reduced", "go-args-env-file/manifests/manifest.reduced.pinned.yaml", "go-args-env-file", None, []),
    ("flask-redis", "flask-redis/k8s/manifest.pinned.yaml", "flask-redis", None, []),
    ("configmap", "configmap/manifest.template.yaml", "configmap", "configmap/Values.yaml", []),
    ("flask-redis-netshield", "flask-redis-netshield/k8s/manifest.template.yaml", "flask-redis-netshield", "flask-redis-netshield/Values.yaml", []),
    ("image-signing", "image-signing/manifest.job.template.yaml", "image-signing", "image-signing/Values.yaml", []),
    ("image-signing-kbs", "image-signing/k8s/kbs.template.yaml", "image-signing", "image-signing/Values.yaml", []),
    ("image-signing-keyprovider", "image-signing/k8s/key-provider.template.yaml", "image-signing", "image-signing/Values.yaml", []),
    ("java-args-env-file", "java-args-env-file/manifests/manifest.template.yaml", "java-args-env-file", "java-args-env-file/Values.yaml", []),
    ("network-policy", "network-policy/manifest.template.yaml", "network-policy", "network-policy/Values.yaml", []),
    ("nfs-shared-volume", "nfs-shared-volume/manifest.template.yaml", "nfs-shared-volume", "nfs-shared-volume/Values.yaml", []),
    ("pet-clinic", "pet-clinic/manifests/petclinic.template.yaml", "pet-clinic", "pet-clinic/Values.yaml", ["pet-clinic/manifests/secret.template.yaml"]),
    ("pet-clinic-db", "pet-clinic/manifests/mariadb.template.yaml", "pet-clinic", "pet-clinic/Values.yaml", ["pet-clinic/manifests/secret.template.yaml"]),
    ("software-updates-v1", "software-updates/k8s/manifest.v1.template.yaml", "software-updates", "software-updates/Values.yaml", []),
    ("software-updates-v2", "software-updates/k8s/manifest.v2.template.yaml", "software-updates", "software-updates/Values.yaml", []),
    ("web-server", "web-server/manifest.template.yaml", "web-server", "web-server/Values.yaml", []),
    ("workshop-registry", "workshop/local-registry.yaml", "workshop", "workshop/Values.yaml", []),
]
# Optional cases (demo-side SPTD variants added on the fix commit); skipped when absent.
OPTIONAL_CASES = [
    ("java-args-env-file-sptd", "java-args-env-file/manifests/manifest.sptd.template.yaml", "java-args-env-file", "java-args-env-file/Values.yaml", []),
    ("web-server-sptd", "web-server/manifest.sptd.template.yaml", "web-server", "web-server/Values.yaml", []),
    ("configmap-sptd", "configmap/manifest.sptd.template.yaml", "configmap", "configmap/Values.yaml", []),
    ("flask-redis-netshield-sptd", "flask-redis-netshield/k8s/manifest.sptd.template.yaml", "flask-redis-netshield", "flask-redis-netshield/Values.yaml", []),
]
WORKLOAD_KINDS = {"Pod": "/spec", "Job": "/spec/template/spec", "Deployment": "/spec/template/spec",
                  "StatefulSet": "/spec/template/spec", "DaemonSet": "/spec/template/spec",
                  "ReplicaSet": "/spec/template/spec", "CronJob": "/spec/jobTemplate/spec/template/spec"}
# Objects some demos create outside their manifests (keys from the demo README / SconeSecret).
EXTERNAL_SECRETS = {
    "redis-tls": ["redis.crt", "redis.key", "redis-ca.crt"],
    "flask-tls": ["flask.crt", "flask.key", "client.crt", "client.key", "redis-ca.crt"],
    "api-credentials": ["API_PASSWORD"],
}
VM163 = {"namespace": "sdv-demos", "node": "sptd-k8s-163", "runtime_class": "scone-process-td"}


def sha(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def pod_of(doc):
    node = doc
    for part in WORKLOAD_KINDS[doc["kind"]].strip("/").split("/"):
        node = node[part]
    return node


def write_json(path, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write("\n")


def load_docs(demos_root, path, values):
    text = open(os.path.join(demos_root, path)).read()
    if values is not None:
        env = (yaml.safe_load(open(os.path.join(demos_root, values))) or {}).get("environment", {})
        text = re.sub(r"\$\{(\w+)\}", lambda m: str(env[m.group(1)]) if m.group(1) in env else m.group(0), text)
    for key, value in SUBST.items():
        text = text.replace(key, value)
    return [d for d in yaml.safe_load_all(text) if isinstance(d, dict)]


class Images:
    def __init__(self, lock, lock_dir, variant):
        self.variant = variant
        self.real = {}
        for entry in lock["images"]:
            cfg = open(os.path.join(lock_dir, entry["config"]["file"]), "rb").read()
            value = (entry["pinned"], cfg, entry["config"], "real")
            self.real[entry["pinned"]] = value
            self.real[entry["reference"]] = value
            if "/" not in entry["reference"]:
                self.real["docker.io/library/" + entry["reference"]] = value
        self.native = []
        for nid, native in lock["native"].items():
            standin = native["stand_in"]["pinned"]
            if variant == "standin":
                ref, cfg, desc = self.real[standin][0], self.real[standin][1], self.real[standin][2]
                label = f"STAND-IN for {native['reference']} (real {native['stand_in']['base_reference']} digest + real config)"
            else:
                syn = native["derived_synthetic"]
                cfg = open(os.path.join(lock_dir, syn["config"]["file"]), "rb").read()
                desc, ref, label = syn["config"], syn["pinned"], f"SYNTHETIC digest + SYNTHETIC derived config for {native['reference']}"
            self.native.append((native.get("demo", nid), native["reference"], standin, (ref, cfg, desc, label)))

    def lookup(self, image, demo):
        """Return (ref, cfg, desc, label) for a container image of `demo`."""
        value = None
        for ndemo, reference, standin, v in self.native:
            if image == reference or (image == standin and ndemo == demo):
                value = v
                break
        if value is None:
            if image not in self.real:
                raise SystemExit(f"{demo}: image {image} is not in images.lock.json")
            value = self.real[image]
        ref, cfg, desc, label = value
        label = ("REAL " + ref) if label == "real" else label
        if self.variant == "probe":
            return probe(ref, cfg, desc, label)
        return ref, cfg, desc, label


def probe(ref, cfg, desc, label):
    """Neutralize image-config blockers; returns a SYNTHETIC probe image."""
    doc = json.loads(cfg)
    changes = [f for f in ("Volumes", "ArgsEscaped") if doc["config"].pop(f, None) is not None]
    for field in ("Entrypoint", "Cmd"):
        argv = doc["config"].get(field) or []
        if argv and argv[0].rsplit("/", 1)[-1] in ("python", "python3"):
            argv[0] = "/usr/local/bin/sdv026-probe-not-python"
            changes.append(f"{field}[0] python renamed")
            break
    if not changes:
        return ref, cfg, desc, label
    cfg = json.dumps(doc, sort_keys=True, separators=(",", ":")).encode()
    desc = {"media_type": desc["media_type"], "size": len(cfg), "digest": sha(cfg)}
    # Probe images are never registry objects: name them under synthetic.invalid.
    ref = "synthetic.invalid/" + ref.rsplit("@", 1)[0].rsplit("/", 1)[-1] + "@" + sha(b"sdv026-synthetic-image:" + desc["digest"].encode())
    return ref, cfg, desc, f"PROBE (SYNTHETIC) from [{label}], removed: {', '.join(changes)}"


def vm163_shape(doc):
    doc["metadata"]["namespace"] = VM163["namespace"]
    pod = pod_of(doc)
    pod["hostNetwork"] = True
    pod["dnsPolicy"] = "ClusterFirstWithHostNet"
    pod["nodeName"] = VM163["node"]
    pod["runtimeClassName"] = VM163["runtime_class"]
    pod["tolerations"] = [{"key": "node.kubernetes.io/not-ready", "operator": "Exists", "effect": "NoSchedule"}]


def references(pod):
    """(kind, name) of every ConfigMap/Secret a pod reads through volumes or env."""
    refs = set()
    for v in pod.get("volumes", []):
        for src in [v] + v.get("projected", {}).get("sources", []):
            if "configMap" in src:
                refs.add(("ConfigMap", src["configMap"]["name"]))
            if "secret" in src:
                refs.add(("Secret", src["secret"].get("secretName") or src["secret"].get("name")))
    for field in ("initContainers", "containers"):
        for c in pod.get(field, []):
            for e in c.get("env", []):
                vf = e.get("valueFrom") or {}
                if "configMapKeyRef" in vf:
                    refs.add(("ConfigMap", vf["configMapKeyRef"]["name"]))
                if "secretKeyRef" in vf:
                    refs.add(("Secret", vf["secretKeyRef"]["name"]))
            for ef in c.get("envFrom", []):
                if "configMapRef" in ef:
                    refs.add(("ConfigMap", ef["configMapRef"]["name"]))
                if "secretRef" in ef:
                    refs.add(("Secret", ef["secretRef"]["name"]))
    return refs


def main():
    demos_root, out_dir, variant = sys.argv[1], sys.argv[2], sys.argv[3]
    assert variant in ("standin", "derived", "probe", "vm163"), variant
    lock_dir = os.path.join(demos_root, "sdv026")
    lock = json.load(open(os.path.join(lock_dir, "images.lock.json")))
    images = Images(lock, lock_dir, "derived" if variant == "vm163" else variant)
    index = []
    cases = CASES + [c for c in OPTIONAL_CASES if os.path.exists(os.path.join(demos_root, c[1]))]
    for case, path, demo, values, extra in cases:
        docs = load_docs(demos_root, path, values)
        objects = [d for d in docs if d["kind"] in ("ConfigMap", "Secret")]
        for e in extra:
            objects += [d for d in load_docs(demos_root, e, values) if d["kind"] in ("ConfigMap", "Secret")]
        for doc in docs:
            kind, name = doc["kind"], doc["metadata"]["name"]
            if kind not in WORKLOAD_KINDS:
                if kind not in ("ConfigMap", "Secret"):
                    index.append({"case": case, "workload": f"{kind}/{name}", "status": "not-a-workload"})
                continue
            doc = copy.deepcopy(doc)
            if variant == "vm163":
                vm163_shape(doc)
            namespace = doc["metadata"].get("namespace")
            root = os.path.join(out_dir, variant, case, name)
            pod = pod_of(doc)
            plan_images, env, env_from, volumes, snapshots, labels = [], [], [], [], [], {}
            for field in ("initContainers", "containers"):
                for c in pod.get(field, []):
                    ref, cfg, desc, label = images.lookup(c["image"], demo)
                    c["image"] = ref
                    labels[c["name"]] = label
                    cfg_path = f"oci/{c['name']}.config.json"
                    os.makedirs(os.path.join(root, "oci"), exist_ok=True)
                    open(os.path.join(root, cfg_path), "wb").write(cfg)
                    assert sha(cfg) == desc["digest"] and len(cfg) == desc["size"]
                    prepared = "registry.example/sdv026-synthetic/prepared@" + sha(f"prepared:{case}:{name}:{c['name']}".encode())
                    plan_images.append({"containerName": c["name"], "sourceImage": ref, "preparedImage": prepared,
                                        "configDescriptor": {k: desc[k] for k in ("media_type", "size", "digest")},
                                        "configPath": cfg_path})
                    for e in c.get("env", []):
                        env.append({"container_name": c["name"], "name": e["name"],
                                    "object_id": "sdv026-env-" + sha(f"{case}/{name}/{c['name']}/{e['name']}".encode())[7:19]})
                    for ef in c.get("envFrom", []):
                        k = "config_map" if "configMapRef" in ef else "secret"
                        src = ef.get("configMapRef") or ef.get("secretRef")
                        env_from.append({"container_name": c["name"], "kind": k, "name": src["name"], "prefix": ef.get("prefix"),
                                         "object_id": "sdv026-envfrom-" + sha(f"{case}/{name}/{c['name']}/{src['name']}".encode())[7:19]})
            for v in pod.get("volumes", []):
                volumes.append({"name": v["name"], "object_id": "sdv026-volume-" + sha(f"{case}/{name}/{v['name']}".encode())[7:19]})
            for skind, sname in sorted(references(pod)):
                obj = next((o for o in objects if o["kind"] == skind and o["metadata"]["name"] == sname), None)
                synthetic = obj is None
                if synthetic:
                    if sname not in EXTERNAL_SECRETS:
                        continue  # compiler reports MissingSnapshot
                    keys = EXTERNAL_SECRETS[sname]
                    obj = {"apiVersion": "v1", "kind": "Secret", "type": "Opaque",
                           "metadata": {"name": sname, **({"namespace": namespace} if namespace else {})},
                           "data": {k: base64.b64encode(f"SDV026-SYNTHETIC-PLACEHOLDER {sname}/{k}\n".encode()).decode() for k in keys}}
                obj = copy.deepcopy(obj)
                normalized = False
                if variant == "vm163" or (namespace and "namespace" not in obj["metadata"]):
                    normalized = obj["metadata"].get("namespace") != namespace
                    obj["metadata"]["namespace"] = namespace
                spath = f"snapshots/{skind.lower()}-{sname}.json"
                write_json(os.path.join(root, spath), obj)
                snapshots.append({"kind": skind, "name": sname, "namespace": obj["metadata"].get("namespace"), "path": spath,
                                  "uid": f"sdv026-synthetic-uid-{sname}", "resource_version": "sdv026-synthetic-1",
                                  **({"_synthetic_object": True} if synthetic else {}),
                                  **({"_namespace_normalized": True} if normalized else {})})
            write_json(os.path.join(root, "workload.json"), doc)
            plan = {"schemaVersion": 1,
                    "workload": {"kind": kind, "namespace": namespace, "name": name, "path": "workload.json",
                                 "uid": f"sdv026-synthetic-uid-{name}", "resource_version": "sdv026-synthetic-1"},
                    "snapshots": [{k: v for k, v in s.items() if not k.startswith("_")} for s in snapshots],
                    # Opaque selectors and object ids: readable ones ("sdv026/flask-redis/flask-api",
                    # "sdv026-env-flask-api-redis-host") contain the protected env value "redis"
                    # and are (correctly) rejected by the public-output canary scan.
                    "bootstrap": {"cas_address": "cas.default:18765",
                                  "config_id": "sdv026/w" + sha(f"{case}/{name}".encode())[7:19]},
                    "images": plan_images, "protectedEnvironment": env,
                    "protectedEnvironmentFrom": env_from, "protectedVolumes": volumes}
            write_json(os.path.join(root, "plan.json"), plan)
            index.append({"case": case, "workload": f"{kind}/{name}", "status": "input",
                          "input_root": os.path.relpath(root, out_dir), "images": labels,
                          "synthetic_snapshots": [s["name"] for s in snapshots if s.get("_synthetic_object")],
                          "namespace_normalized": [s["name"] for s in snapshots if s.get("_namespace_normalized")]})
    write_json(os.path.join(out_dir, variant, "index.json"), index)
    print(json.dumps(index, indent=2))


if __name__ == "__main__":
    main()
