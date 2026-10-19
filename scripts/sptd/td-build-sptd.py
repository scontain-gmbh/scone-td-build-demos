#!/usr/bin/env python3
"""sptd mode for `scone-td-build apply -f scone.yaml` (docs/sptd-mode.md). NON_RELEASE.

Reads the Register and Apply documents of scone.yaml and, for every workload in the
Apply files, prepares each registered container with `sptd-dev-prepare`
(scone-sptd-build, built with --features rfa-development):

  1. copy the native image (Register source-image) to a local OCI layout (skopeo)
  2. phase 1: embedded configuration and its digest
  3. build the static development envcas launcher with that configuration embedded
  4. phase 2: OCI layout + confidential manifest (+ input accounting)
  5. sign with $SPTD_SIGN_CMD if set (PR #108 onboarding tooling), else stay unsigned
  6. push the layout to the Register output-image repository (skopeo)

Then it writes the Apply output-manifest: every non-workload document unchanged, every
workload replaced by its confidential manifest, reshaped for the single-node demo
cluster until S7 (hostNetwork, nodeName, not-ready toleration).

Development only: CAS is bypassed, envcas attestation is disabled, embedded values and
ConfigMap files are public plaintext in the image. Never use it with real secrets.

Environment:
  SPTD_DEV_PREPARE     path to the sptd-dev-prepare binary (default: sptd-dev-prepare in PATH)
  SPTD_BUILD_SRC       scone-sptd-build checkout (for examples/clock/development-envcas)
  SPTD_WORK_DIR        work directory (default: ./.sptd-work)
  SPTD_NODE_NAME       node name for nodeName (default: unset, no nodeName)
  SPTD_RUNTIME_CLASS   RuntimeClass for prepared Pods (default scone-process-td, the class
                       the node archive installs with handler scone)
  SPTD_HOST_NETWORK    "false" to keep the Pod network (default: true until S7)
  SPTD_SIGN_CMD        command run as: $SPTD_SIGN_CMD <oci-layout> <confidential-manifest>
  SPTD_PUSH            "false" to skip the registry push (preload instead)
"""
import argparse, hashlib, json, os, re, shlex, shutil, subprocess, sys

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("td-build-sptd: PyYAML is required (python3 -m pip install pyyaml)")

WORKLOAD_PODS = {"Pod": ["spec"], "Job": ["spec", "template", "spec"],
                 "Deployment": ["spec", "template", "spec"], "StatefulSet": ["spec", "template", "spec"],
                 "DaemonSet": ["spec", "template", "spec"], "ReplicaSet": ["spec", "template", "spec"],
                 "CronJob": ["spec", "jobTemplate", "spec", "template", "spec"]}


def log(msg):
    print(f"scone-td-build (sptd mode): {msg}", file=sys.stderr, flush=True)


def run(cmd, **kw):
    log("+ " + " ".join(shlex.quote(c) for c in cmd))
    return subprocess.run(cmd, check=True, **kw)


def pod_spec(doc):
    node = doc
    for key in WORKLOAD_PODS[doc["kind"]]:
        node = node[key]
    return node


def load_yaml_docs(path):
    with open(path) as f:
        return [d for d in yaml.safe_load_all(f) if isinstance(d, dict)]


def image_repository(ref):
    """registry/name[:tag][@digest] -> registry/name"""
    ref = ref.split("@", 1)[0]
    last = ref.rsplit("/", 1)
    if ":" in last[-1]:
        ref = ref[: ref.rfind(":")]
    return ref


def file_digest(path):
    with open(path, "rb") as f:
        return "sha256:" + hashlib.sha256(f.read()).hexdigest()


def pull_layout(image, layout):
    """image: a registry reference, or docker-daemon:<ref> for a locally built image."""
    if os.path.exists(layout):
        shutil.rmtree(layout)
    source = image if image.startswith("docker-daemon:") else f"docker://{image}"
    run(["skopeo", "copy", "--override-os", "linux", "--override-arch", "amd64",
         source, f"oci:{layout}:source"])
    index = json.load(open(os.path.join(layout, "index.json")))
    manifests = index.get("manifests", [])
    if len(manifests) != 1:
        raise SystemExit(f"{image}: expected one manifest in the pulled layout, got {len(manifests)}")
    return manifests[0]["digest"]


def report_of(stdout):
    try:
        return json.loads(stdout)
    except json.JSONDecodeError:
        raise SystemExit("sptd-dev-prepare did not print a JSON report:\n" + stdout)


def build_launcher(embedded, target_dir, out_dir):
    src = os.environ.get("SPTD_BUILD_SRC")
    if not src:
        raise SystemExit("SPTD_BUILD_SRC must point at a scone-sptd-build checkout")
    env = dict(os.environ, SCONE_CLOCK_DEVELOPMENT_CONFIG=embedded,
               RUSTFLAGS="-C target-feature=+crt-static")
    run(["cargo", "build", "--manifest-path",
         os.path.join(src, "examples/clock/development-envcas/Cargo.toml"), "--locked", "--release",
         "--target", "x86_64-unknown-linux-gnu", "--target-dir", target_dir], env=env)
    built = [os.path.join(target_dir, "x86_64-unknown-linux-gnu", "release", n)
             for n in ("envcas", "development-envcas")]
    built = next((b for b in built if os.path.isfile(b)), None)
    if built is None:
        raise SystemExit("development envcas launcher binary not found after cargo build")
    os.makedirs(out_dir, exist_ok=True)
    shutil.copyfile(built, os.path.join(out_dir, "envcas"))
    os.chmod(os.path.join(out_dir, "envcas"), 0o755)
    return file_digest(os.path.join(out_dir, "envcas"))


def configmaps_for(pod, container, configmaps, work):
    names = {v["configMap"]["name"] for v in pod.get("volumes", []) if "configMap" in v}
    mounted = {m["name"] for m in container.get("volumeMounts", [])}
    used = {v["configMap"]["name"] for v in pod.get("volumes", [])
            if "configMap" in v and v["name"] in mounted}
    files = []
    for name in sorted(names & used):
        if name not in configmaps:
            raise SystemExit(f"ConfigMap {name} is not in the Apply files")
        path = os.path.join(work, f"configmap-{name}.json")
        json.dump(configmaps[name], open(path, "w"), indent=2, sort_keys=True)
        files.append(path)
    return files


def prepare_container(tool, workload_path, doc, container, image, target, configmaps, work):
    repo = image_repository(target)
    cwork = os.path.join(work, doc["metadata"]["name"], container["name"])
    os.makedirs(cwork, exist_ok=True)
    out = os.path.join(cwork, "out")
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)
    digest = pull_layout(image, os.path.join(cwork, "source"))
    common = [tool, "--image-layout", os.path.join(cwork, "source"), "--image-digest", digest,
              "--workload", workload_path, "--container", container["name"], "--output", out,
              "--ignore-workload-image-digest"]
    for cm in configmaps_for(pod_spec(doc), container, configmaps, cwork):
        common += ["--configmap", cm]
    phase1 = report_of(run(common + ["--generation", "inputs"], capture_output=True, text=True).stdout)
    config_digest = phase1["configuration_digest"]
    envcas_digest = build_launcher(os.path.join(out, "inputs", "embedded.json"),
                                   os.path.join(cwork, "launcher-target"), os.path.join(cwork, "launcher"))
    phase2 = report_of(run(common + ["--generation", "image", "--launcher-root", os.path.join(cwork, "launcher"),
                                     "--envcas", "envcas", "--envcas-digest", envcas_digest,
                                     "--image-repository", repo,
                                     "--expect-configuration-digest", config_digest],
                           capture_output=True, text=True).stdout)
    layout = os.path.join(out, "image")
    manifest = os.path.join(out, "image-manifest", "confidential-manifest.json")
    sign = os.environ.get("SPTD_SIGN_CMD")
    if sign:
        run(shlex.split(sign) + [layout, manifest])
    else:
        log(f"{container['name']}: SPTD_SIGN_CMD not set, image stays unsigned")
    image_digest = phase2.get("image_digest") or json.load(open(os.path.join(layout, "index.json")))["manifests"][0]["digest"]
    if os.environ.get("SPTD_PUSH", "true") != "false":
        # Push under the Register output-image tag, keeping the digest the manifest pins.
        tagged = target if "@" not in target else repo + ":sptd"
        run(["skopeo", "copy", "--preserve-digests", f"oci:{layout}", f"docker://{tagged}"])
    return manifest


def shape_for_node(doc):
    pod = pod_spec(doc)
    pod["runtimeClassName"] = os.environ.get("SPTD_RUNTIME_CLASS", "scone-process-td")
    if os.environ.get("SPTD_HOST_NETWORK", "true") != "false":
        pod["hostNetwork"] = True
        pod["dnsPolicy"] = "ClusterFirstWithHostNet"
        tolerations = pod.setdefault("tolerations", [])
        toleration = {"key": "node.kubernetes.io/not-ready", "operator": "Exists", "effect": "NoSchedule"}
        if toleration not in tolerations:
            tolerations.append(toleration)
    if os.environ.get("SPTD_NODE_NAME"):
        pod["nodeName"] = os.environ["SPTD_NODE_NAME"]


def sptd_variant(base, name):
    """Use <stem>.sptd.template.yaml (rendered to <stem>.sptd.yaml) when a demo ships one.

    Some demos keep an sptd-only manifest variant beside the regular template, for
    example a projected volume instead of a subPath mount. The README renders only the
    regular template, so render the variant here the same way (tplenv, or ${VAR}
    substitution from the environment when tplenv is unavailable).
    """
    stem = name[: -len(".yaml")] if name.endswith(".yaml") else name
    template = os.path.join(base, stem + ".sptd.template.yaml")
    if not os.path.isfile(template):
        return name
    rendered = stem + ".sptd.yaml"
    target = os.path.join(base, rendered)
    if shutil.which("tplenv"):
        run(["tplenv", "--file", template, "--create-values-file", "--output", target], cwd=base)
    else:
        text = open(template).read()
        text = re.sub(r"\$\{(\w+)\}", lambda m: os.environ.get(m.group(1), m.group(0)), text)
        open(target, "w").write(text)
    log(f"using sptd variant {rendered} for {name}")
    return rendered


def sptd_source_image(base, image):
    """Build <demo>/Dockerfile.sptd when a demo ships one, and use it as the sptd source.

    Some demos need a different native image for sptd (for example a run stage without
    VOLUME), while sgx/cvm keep the regular Dockerfile. The image stays local: it is
    read from the Docker daemon, not pushed.
    """
    directory, root = base, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    root = os.path.dirname(root)  # repository root (scripts/sptd/.. /..)
    while True:
        dockerfile = os.path.join(directory, "Dockerfile.sptd")
        if os.path.isfile(dockerfile):
            break
        parent = os.path.dirname(directory)
        if directory == root or parent == directory:
            return image
        directory = parent
    repo = image_repository(image)
    tag = f"{repo}:sptd-source"
    run(["docker", "build", "-f", dockerfile, "-t", tag, directory])
    log(f"using {os.path.relpath(dockerfile, root)} for the sptd source of {image}")
    return f"docker-daemon:{tag}"


def apply(scone_yaml):
    base = os.path.dirname(os.path.abspath(scone_yaml))
    docs = load_yaml_docs(scone_yaml)
    registers = [d["spec"] for d in docs if d.get("kind") == "Register"]
    applies = [d["spec"] for d in docs if d.get("kind") == "Apply"]
    if not applies:
        raise SystemExit(f"{scone_yaml}: no Apply document")
    images = {r["source-image"]: r.get("output-image") or r["source-image"] for r in registers}
    tool = os.environ.get("SPTD_DEV_PREPARE") or shutil.which("sptd-dev-prepare")
    if not tool:
        raise SystemExit("sptd-dev-prepare not found (set SPTD_DEV_PREPARE)")
    work = os.path.abspath(os.environ.get("SPTD_WORK_DIR", ".sptd-work"))
    os.makedirs(work, exist_ok=True)
    for spec in applies:
        files = spec["file"] if isinstance(spec["file"], list) else [spec["file"]]
        files = [sptd_variant(base, f) for f in files]
        inputs = [d for f in files for d in load_yaml_docs(os.path.join(base, f))]
        configmaps = {d["metadata"]["name"]: d for d in inputs if d.get("kind") == "ConfigMap"}
        output = []
        for doc in inputs:
            if doc.get("kind") not in WORKLOAD_PODS:
                output.append(doc)
                continue
            current = os.path.join(work, f"{doc['kind'].lower()}-{doc['metadata']['name']}.json")
            json.dump(doc, open(current, "w"), indent=2, sort_keys=True)
            prepared = 0
            for container in pod_spec(doc).get("containers", []):
                if container["image"] not in images:
                    log(f"{doc['metadata']['name']}/{container['name']}: image {container['image']} "
                        "is not registered in scone.yaml; left unchanged")
                    continue
                source = sptd_source_image(base, container["image"])
                current = prepare_container(tool, current, json.load(open(current)), container,
                                            source, images[container["image"]], configmaps, work)
                prepared += 1
            result = json.load(open(current))
            if prepared:
                shape_for_node(result)
            output.append(result)
        target = os.path.join(base, spec["output-manifest"])
        with open(target, "w") as f:
            yaml.safe_dump_all(output, f, sort_keys=False)
        log(f"wrote {spec['output-manifest']} (development only: CAS bypassed, public plaintext)")


def main():
    parser = argparse.ArgumentParser(prog="td-build-sptd")
    sub = parser.add_subparsers(dest="command", required=True)
    a = sub.add_parser("apply")
    a.add_argument("--file", required=True)
    args = parser.parse_args()
    try:
        apply(args.file)
    except subprocess.CalledProcessError as error:
        if error.stdout:
            sys.stderr.write(error.stdout if isinstance(error.stdout, str) else error.stdout.decode())
        if error.stderr:
            sys.stderr.write(error.stderr if isinstance(error.stderr, str) else error.stderr.decode())
        log(f"failed: {' '.join(error.cmd)} (rc={error.returncode})")
        sys.exit(1)


if __name__ == "__main__":
    main()
