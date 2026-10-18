#!/usr/bin/env python3
"""Add anonymously resolved base images and SYNTHETIC derived native configs to images.lock.json.

Temporary SDV-026 harness, not a product tool.

Usage: derive_configs.py DEMOS_ROOT RESOLVE_DIR

RESOLVE_DIR is the output of resolve_digests.py (digests.json + <ref>.config.json).
Every successfully resolved reference is added to lock["images"] (kind "real") and its
exact config blob copied to sdv026/oci-configs/. Every reference that failed (the
registry.scontain.com native images answer HTTP 403 anonymously) and is listed in
NATIVES gets a lock["native"][<id>] entry with:

  stand_in           the real digest of the Dockerfile's final-stage base image
  derived_synthetic  a SYNTHETIC config: the base config with the final stage's
                     ENTRYPOINT/CMD/USER/WORKDIR/ENV/VOLUME/EXPOSE applied (Docker
                     semantics: ENTRYPOINT resets an inherited CMD), plus the label
                     org.sdv026.synthetic.source=<native reference>, and a SYNTHETIC
                     digest under synthetic.invalid/. It is never a registry object.

Existing lock entries are left byte-for-byte unchanged.
"""
import json, os, re, shlex, sys, hashlib

# id -> (demo dir, native reference, Dockerfile, build args)
NATIVES = {
    "configmap": ("configmap", "registry.scontain.com/k8s-scone-images/configmap:native", "configmap/folder-reader/Dockerfile", {}),
    "network-policy-client": ("network-policy", "registry.scontain.com/k8s-scone-images/network-policy:client", "network-policy/client/Dockerfile", {}),
    "network-policy-server": ("network-policy", "registry.scontain.com/k8s-scone-images/network-policy:server", "network-policy/server/Dockerfile", {}),
    "nfs-shared-volume": ("nfs-shared-volume", "registry.scontain.com/k8s-scone-images/nfs-shared-io:demo", "nfs-shared-volume/Dockerfile", {}),
    "web-server": ("web-server", "registry.scontain.com/k8s-scone-images/web-server:native", "web-server/Dockerfile", {}),
    "flask-redis-netshield": ("flask-redis-netshield", "registry.scontain.com/k8s-scone-images/flask-redis:latest-netshield", "flask-redis-netshield/Dockerfile", {}),
    "image-signing": ("image-signing", "registry.scontain.com/k8s-scone-images/image-signing:native", "image-signing/Dockerfile", {}),
    "java-args-env-file": ("java-args-env-file", "registry.scontain.com/k8s-scone-images/java-args-env-file:native", "java-args-env-file/Dockerfile", {}),
    "pet-clinic": ("pet-clinic", "registry.scontain.com/k8s-scone-images/pet-clinic:native", "pet-clinic/Dockerfile", {}),
    "software-updates-v1": ("software-updates", "registry.scontain.com/k8s-scone-images/software-updates:v1", "software-updates/Dockerfile", {"VERSION": "1"}),
    "software-updates-v2": ("software-updates", "registry.scontain.com/k8s-scone-images/software-updates:v2", "software-updates/Dockerfile", {"VERSION": "2"}),
}


def sha(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def instructions(path):
    """Yield (INSTRUCTION, rest) with line continuations joined and comments dropped."""
    buf = ""
    for line in open(path):
        stripped = line.strip()
        if not buf and (not stripped or stripped.startswith("#")):
            continue
        if stripped.startswith("#"):
            continue
        if stripped.endswith("\\"):
            buf += stripped[:-1] + " "
            continue
        buf += stripped
        word, _, rest = buf.partition(" ")
        yield word.upper(), rest.strip()
        buf = ""


def argv(rest):
    rest = rest.strip()
    if rest.startswith("["):
        return json.loads(rest)
    return ["/bin/sh", "-c", rest]  # shell form


def final_stage(path, build_args):
    args, stages = dict(build_args), []
    for word, rest in instructions(path):
        if word == "ARG":
            name, _, default = rest.partition("=")
            args.setdefault(name.strip(), default.strip().strip('"'))
        elif word == "FROM":
            parts = rest.split()
            base = re.sub(r"\$\{?(\w+)\}?", lambda m: args.get(m.group(1), ""), parts[0])
            stages.append({"base": base, "ops": []})
        elif stages:
            stages[-1]["ops"].append((word, rest))
    stage = stages[-1]
    if ":" not in stage["base"].rsplit("/", 1)[-1] and "@" not in stage["base"]:
        stage["base"] += ":latest"
    return stage, args


def derive(base_cfg_bytes, stage, args, reference):
    doc = json.loads(base_cfg_bytes)
    cfg = doc.setdefault("config", {})
    applied = {}
    env = dict(e.split("=", 1) for e in cfg.get("Env") or [])
    for word, rest in stage["ops"]:
        if word == "ENTRYPOINT":
            cfg["Entrypoint"] = argv(rest)
            cfg.pop("Cmd", None)  # Docker: ENTRYPOINT resets the inherited CMD
            applied["Entrypoint"] = cfg["Entrypoint"]
            applied.setdefault("Cmd", None)
        elif word == "CMD":
            cfg["Cmd"] = argv(rest)
            applied["Cmd"] = cfg["Cmd"]
        elif word == "WORKDIR":
            cfg["WorkingDir"] = rest
            applied["WorkingDir"] = rest
        elif word == "USER":
            cfg["User"] = rest
            applied["User"] = rest
        elif word == "ENV":
            if "=" in rest.split()[0]:
                for item in shlex.split(rest):
                    k, _, v = item.partition("=")
                    env[k] = v
            else:
                k, _, v = rest.partition(" ")
                env[k] = v.strip()
            cfg["Env"] = [f"{k}={v}" for k, v in env.items()]
            applied["Env"] = cfg["Env"]
        elif word == "VOLUME":
            vols = argv(rest) if rest.startswith("[") else rest.split()
            cfg.setdefault("Volumes", {}).update({v: {} for v in vols})
            applied["Volumes"] = cfg["Volumes"]
        elif word == "EXPOSE":
            for p in rest.split():
                cfg.setdefault("ExposedPorts", {})[p if "/" in p else p + "/tcp"] = {}
            applied["ExposedPorts"] = cfg["ExposedPorts"]
    labels = cfg.get("Labels") or {}
    labels["org.sdv026.synthetic.source"] = "SYNTHETIC derived config for " + reference
    cfg["Labels"] = labels
    return json.dumps(doc, sort_keys=True, separators=(",", ":")).encode(), applied


def main():
    demos_root, resolve_dir = sys.argv[1], sys.argv[2]
    lock_dir = os.path.join(demos_root, "sdv026")
    lock_path = os.path.join(lock_dir, "images.lock.json")
    lock = json.load(open(lock_path))
    have = {e["reference"] for e in lock["images"]}
    by_ref = {e["reference"]: e for e in lock["images"]}
    results = json.load(open(os.path.join(resolve_dir, "digests.json")))
    for r in results:
        if "error" in r or r["reference"] in have:
            continue
        blob = open(os.path.join(resolve_dir, r["config"]["file"]), "rb").read()
        name = r["config"]["file"]
        open(os.path.join(lock_dir, "oci-configs", name), "wb").write(blob)
        entry = {"reference": r["reference"], "kind": "real", "resolved_at": r["resolved_at"],
                 "pinned": r["pinned"], "amd64_manifest_digest": r["amd64_manifest_digest"],
                 "amd64_manifest_media_type": r["amd64_manifest_media_type"],
                 "index_digest": r.get("index_digest"), "index_media_type": r.get("top_media_type") if r.get("index_digest") else None,
                 "config": {k: r["config"][k] for k in ("media_type", "size", "digest")} | {"file": "oci-configs/" + name}}
        lock["images"].append(entry)
        by_ref[entry["reference"]] = entry
    failed = {r["reference"]: r for r in results if "error" in r}
    for nid, (demo, reference, dockerfile, build_args) in NATIVES.items():
        if nid in lock["native"]:
            continue
        if reference not in failed:
            raise SystemExit(f"{reference}: not in the resolver output as a failure; refusing to synthesize")
        stage, args = final_stage(os.path.join(demos_root, dockerfile), build_args)
        base = by_ref.get(stage["base"])
        if base is None:
            raise SystemExit(f"{nid}: base {stage['base']} not resolved")
        base_cfg = open(os.path.join(lock_dir, base["config"]["file"]), "rb").read()
        cfg, applied = derive(base_cfg, stage, args, reference)
        desc = {"media_type": base["config"]["media_type"], "size": len(cfg), "digest": sha(cfg)}
        fname = f"oci-configs/SYNTHETIC-derived-{nid}.config.json"
        open(os.path.join(lock_dir, fname), "wb").write(cfg)
        repo = reference.rsplit(":", 1)[0].rsplit("/", 1)[-1]
        lock["native"][nid] = {
            "demo": demo,
            "reference": reference,
            "anonymous_resolution": {"resolved_at": failed[reference]["resolved_at"], "result": failed[reference]["error"]},
            "stand_in": {"kind": "stand-in", "base_reference": stage["base"], "pinned": base["pinned"],
                         "why": "native image is access-forbidden anonymously; Dockerfile final-stage base image digest used instead; it does not contain the demo app"},
            "derived_synthetic": {
                "kind": "synthetic",
                "pinned": f"synthetic.invalid/{repo}@" + sha(b"sdv026-synthetic-image:" + desc["digest"].encode()),
                "why": "SYNTHETIC digest (sha256 of 'sdv026-synthetic-image:'+config digest), not a registry object; config = final-stage base config with the Dockerfile's ENTRYPOINT/CMD/USER/WORKDIR/ENV/VOLUME/EXPOSE applied (derive_configs.py)",
                "dockerfile": dockerfile, "build_args": build_args,
                "dockerfile_changes": applied,
                "config": desc | {"file": fname},
            },
        }
    json.dump(lock, open(lock_path, "w"), indent=2)
    open(lock_path, "a").write("\n")
    for nid, n in lock["native"].items():
        print(nid, n["derived_synthetic"]["pinned"], json.dumps(n["derived_synthetic"].get("dockerfile_changes")))


if __name__ == "__main__":
    main()
