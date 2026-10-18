#!/usr/bin/env python3
"""Generate scone-sptd-build offline inputs (one input root per workload) for SDV-026.

Temporary SDV-026 harness, not a product tool. It reads the digest-pinned demo
manifests of this branch plus sdv026/images.lock.json and writes, for every
workload document, an input root accepted by `scone-sptd-build build`:

    <out>/<variant>/<case>/<workload>/{workload.json, plan.json, snapshots/, oci/}

Variants:
  standin          image = base-image digest (real registry object) + its real config
  derived          image = SYNTHETIC digest under synthetic.invalid/<name> + SYNTHETIC
                   config (base config with the Dockerfile's ENTRYPOINT/CMD/... applied)
  probe            PROBE ONLY, never a deployable input: like derived, but every image
                   config (including the real redis one) has the execution controls
                   Volumes/ArgsEscaped removed and a python argv[0] renamed, so the
                   compiler reports the next workload-level blocker. All probe images
                   get SYNTHETIC digests.

Everything not taken from the demo manifests is synthetic and labelled so:
snapshot uids/resourceVersions, bootstrap selectors, prepared-image digests,
protected object ids, and the TLS Secret snapshots that flask-redis creates
outside its manifest (placeholder bytes, no key material).

Usage: make_sptd_inputs.py DEMOS_ROOT OUT_DIR VARIANT
"""
import base64, copy, hashlib, json, os, sys

import yaml

SUBST = {"${IMAGE_PULL_SECRET_NAME}": "sconeapps", "${NAMESPACE}": "scone-tools"}
CASES = [
    ("hello-world", "hello-world/manifest.job.pinned.yaml", "hello-world"),
    ("go-args-env-file", "go-args-env-file/manifests/manifest.pinned.yaml", "go-args-env-file"),
    ("go-args-env-file-reduced", "go-args-env-file/manifests/manifest.reduced.pinned.yaml", "go-args-env-file"),
    ("flask-redis", "flask-redis/k8s/manifest.pinned.yaml", "flask-redis"),
]
WORKLOAD_KINDS = {"Pod": "/spec", "Job": "/spec/template/spec", "Deployment": "/spec/template/spec",
                  "StatefulSet": "/spec/template/spec", "DaemonSet": "/spec/template/spec",
                  "ReplicaSet": "/spec/template/spec", "CronJob": "/spec/jobTemplate/spec/template/spec"}
# Secrets the flask-redis README creates with openssl outside the manifest (keys from the README).
EXTERNAL_SECRETS = {
    "redis-tls": ["redis.crt", "redis.key", "redis-ca.crt"],
    "flask-tls": ["flask.crt", "flask.key", "client.crt", "client.key", "redis-ca.crt"],
}


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


def image_inputs(lock, lock_dir, variant):
    """Map pinned stand-in reference -> (workload image, config bytes, descriptor, label)."""
    out = {}
    for entry in lock["images"]:
        cfg = open(os.path.join(lock_dir, entry["config"]["file"]), "rb").read()
        out[entry["pinned"]] = (entry["pinned"], cfg, entry["config"], "real")
    for demo, native in lock["native"].items():
        standin = native["stand_in"]["pinned"]
        if variant == "standin":
            ref, cfg, desc = out[standin][0], out[standin][1], out[standin][2]
            label = f"STAND-IN for {native['reference']} (real {native['stand_in']['base_reference']} digest + real config)"
        else:
            syn = native["derived_synthetic"]
            cfg = open(os.path.join(lock_dir, syn["config"]["file"]), "rb").read()
            desc, ref, label = syn["config"], syn["pinned"], f"SYNTHETIC digest + SYNTHETIC derived config for {native['reference']}"
        out[("native", demo)] = (standin, ref, cfg, desc, label)
    if variant == "probe":
        for key, value in list(out.items()):
            if key[0] == "native":
                out[key] = (value[0],) + probe(*value[1:])
            else:
                out[key] = probe(*value)
    return out


def probe(ref, cfg, desc, label):
    """Neutralize image-config blockers; returns a SYNTHETIC probe image."""
    label = ("REAL " + ref) if label == "real" else label
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


def main():
    demos_root, out_dir, variant = sys.argv[1], sys.argv[2], sys.argv[3]
    assert variant in ("standin", "derived", "probe"), variant
    lock_dir = os.path.join(demos_root, "sdv026")
    lock = json.load(open(os.path.join(lock_dir, "images.lock.json")))
    images = image_inputs(lock, lock_dir, variant)
    index = []
    for case, path, demo in CASES:
        text = open(os.path.join(demos_root, path)).read()
        for key, value in SUBST.items():
            text = text.replace(key, value)
        docs = [d for d in yaml.safe_load_all(text) if isinstance(d, dict)]
        objects = [d for d in docs if d["kind"] in ("ConfigMap", "Secret")]
        for doc in docs:
            kind, name = doc["kind"], doc["metadata"]["name"]
            if kind not in WORKLOAD_KINDS:
                if kind not in ("ConfigMap", "Secret"):
                    index.append({"case": case, "workload": f"{kind}/{name}", "status": "not-a-workload"})
                continue
            doc = copy.deepcopy(doc)
            namespace = doc["metadata"].get("namespace")
            root = os.path.join(out_dir, variant, case, name)
            pod = pod_of(doc)
            native = images[("native", demo)]
            plan_images, env, volumes, snapshots, labels = [], [], [], [], {}
            for field in ("initContainers", "containers"):
                for c in pod.get(field, []):
                    if c["image"] == native[0]:
                        ref, cfg, desc, label = native[1], native[2], native[3], native[4]
                    else:
                        ref, cfg, desc, label = images[c["image"]]
                        label = ("REAL " + ref) if label == "real" else label
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
            referenced = set()
            for v in pod.get("volumes", []):
                volumes.append({"name": v["name"], "object_id": "sdv026-volume-" + sha(f"{case}/{name}/{v['name']}".encode())[7:19]})
                for src in [v] + v.get("projected", {}).get("sources", []):
                    if "configMap" in src:
                        referenced.add(("ConfigMap", src["configMap"]["name"]))
                    if "secret" in src:
                        referenced.add(("Secret", src["secret"].get("secretName") or src["secret"].get("name")))
            for skind, sname in sorted(referenced):
                obj = next((o for o in objects if o["kind"] == skind and o["metadata"]["name"] == sname), None)
                synthetic = obj is None
                if synthetic:
                    keys = EXTERNAL_SECRETS[sname]
                    obj = {"apiVersion": "v1", "kind": "Secret", "type": "Opaque",
                           "metadata": {"name": sname, **({"namespace": namespace} if namespace else {})},
                           "data": {k: base64.b64encode(f"SDV026-SYNTHETIC-PLACEHOLDER {sname}/{k}\n".encode()).decode() for k in keys}}
                spath = f"snapshots/{skind.lower()}-{sname}.json"
                write_json(os.path.join(root, spath), obj)
                snapshots.append({"kind": skind, "name": sname, "namespace": namespace, "path": spath,
                                  "uid": f"sdv026-synthetic-uid-{sname}", "resource_version": "sdv026-synthetic-1",
                                  **({"_synthetic_object": True} if synthetic else {})})
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
                    "protectedEnvironmentFrom": [], "protectedVolumes": volumes}
            write_json(os.path.join(root, "plan.json"), plan)
            index.append({"case": case, "workload": f"{kind}/{name}", "status": "input",
                          "input_root": os.path.relpath(root, out_dir), "images": labels,
                          "synthetic_snapshots": [s["name"] for s in snapshots if s.get("_synthetic_object")]})
    write_json(os.path.join(out_dir, variant, "index.json"), index)
    print(json.dumps(index, indent=2))


if __name__ == "__main__":
    main()
