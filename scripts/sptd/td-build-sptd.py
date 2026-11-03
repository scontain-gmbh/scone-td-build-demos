#!/usr/bin/env python3
"""sptd mode for `scone-td-build apply -f scone.yaml` (docs/sptd-mode.md). NON_RELEASE.

Reads the Register and Apply documents of scone.yaml and turns every registered container
of every workload in the Apply files into a SCONE Process TD dev image. Two routes:

SPTD_ROUTE=a8 (default): A8 offline onboarding (sptd-hello-container-dev
`scone-dev-onboard/onboard.py REQUEST.json FRESH_OUTPUT_DIR`). Per container:

  1. the native image (Register source-image) as a pinned OCI archive: a local layout or
     archive from $SPTD_SOURCE_LAYOUTS, else `skopeo copy docker://… oci-archive:…`
  2. a one-container Pod (the workload's Pod template, image pinned to the manifest
     digest, automountServiceAccountToken and enableServiceLinks false), the ConfigMap
     and Secret snapshots it references from the Apply files, the launch-contract
     policy (scripts/sptd/policies/<demo>.json, else generic.json) and the request
  3. onboard.py: EROFS + dm-verity rootfs, envcas launch contract, sealed launcher,
     signed profile, signed registry (appended across the containers of one run)
  4. a check of the bundle: checksums, signed profile, runtimeReady false

  The output-manifest uses each bundle's rewritten container (envcas-rs activate, image
  pinned to the bundle's reference) with RuntimeClass scone-dev. A multi-role workload or
  one with a memory emptyDir gets role-only bundles, one signed Pod plan (pod_plan.py,
  collected in $SPTD_WORK_DIR/a8/pod-plans/ with its unsigned request) and is written as a
  bare Pod. Bundles are offline preload bundles: nothing is installed or pushed, and the
  node must preload them (and the plans) before the Pods can start.

SPTD_ROUTE=dev-prepare: scone-sptd-build `sptd-dev-prepare` (built with
--features rfa-development):

  1. copy the native image (Register source-image) to a local OCI layout (skopeo)
  2. phase 1: embedded configuration and its digest
  3. build the static development envcas launcher with that configuration embedded
  4. phase 2: OCI layout + confidential manifest (+ input accounting)
  5. sign with $SPTD_SIGN_CMD if set (PR #108 onboarding tooling), else stay unsigned
  6. push the layout to the Register output-image repository (skopeo)

Both routes then write the Apply output-manifest: every non-workload document unchanged,
every prepared workload reshaped for the single-node demo cluster until S7 (hostNetwork,
nodeName, not-ready toleration).

Development only: CAS is bypassed, envcas attestation is disabled. Never use it with real
secrets or a real signing key.

Environment (both routes):
  SPTD_ROUTE           a8 (default) or dev-prepare
  SPTD_WORK_DIR        work directory (default: ./.sptd-work)
  SPTD_NODE_NAME       node name for nodeName (default: unset, no nodeName)
  SPTD_RUNTIME_CLASS   RuntimeClass for prepared Pods (default scone-dev, the dev class with
                       handler scone-dev; scone-process-td is the protected-application class)
  SPTD_HOST_NETWORK    "false" to keep the Pod network (default: true until S7)
  SPTD_DEV_LINT        optional scone-sptd-build `sptd-dev-lint` binary: pre-flight lint of every
                       Apply file (--path offline for controllers); findings (exit 3) stop the run

Environment (a8):
  SPTD_ONBOARD         path to scone-dev-onboard/onboard.py (required)
  SPTD_A8_TOOLS        JSON file with onboard's `tools` object: rootfs_build, rootfs_verify,
                       compiler, emitter, signer, cargo, envcas_source (required)
  SPTD_A8_CARGO_TARGET cargo target dir for the sealed launcher build (optional)
  SPTD_DEV_SIGNING_KEY Ed25519 dev signing key (PEM) for profile and registry (required;
                       never generated here)
  SPTD_DEV_ROOT_PIN    sha256: pin of that key's domain-separated SPKI (required)
  SPTD_POLICY_DIR      policy templates (default: scripts/sptd/policies)
  SPTD_SOURCE_LAYOUTS  JSON file {source-image: OCI layout dir or oci-archive tar}; such
                       images are read locally instead of with skopeo
  SPTD_A8_REGISTRY     existing signed profile-registry.json to append to (optional)
  SPTD_A8_TAG          registry tag prefix; each entry is <prefix>-<profile> (default: sptd-dev)
  SPTD_A8_OFFLINE      "true": refuse images that are not in SPTD_SOURCE_LAYOUTS (no skopeo)
  SPTD_A8_MEMORY_ASSEMBLY  sptd-dev-memory-assembly-v1 JSON for containers with a memory emptyDir;
                       SPTD_A8_TOOLS then also names memory_empty_dir (sptd-build NON_RELEASE
                       sptd-dev-memory-empty-dir)
  SPTD_A8_COMPILER_FEATURES  comma-separated features the compiler was built with; baked volumes
                       need nonrelease-dev-baked-volumes (rust-envcas scone-td-dev-compile)

Per-demo overrides (a8, NON_RELEASE): <policies>/<demo>.overrides.json changes the sptd build of
named workloads only, never the demo's own manifests or the sgx/cvm modes. Per container:
  bakedVolumes     ConfigMap/Secret volumes to bake into the sealed launcher as /dev/fd/N
                   descriptor files ({name, content_pin: true}); onboard.py removes them and
                   their mounts from the Pod, and the Pod plan never declares them
  configRewrites   {configMap, key, directives}: in that baked ConfigMap value, each line
                   "<directive> <path>" whose path is a baked file gets that file's descriptor
  command          explicit command; {"descriptor": "<original path>"} becomes /proc/self/fd/N
  memoryEmptyDirs  {name, mountPath, sizeLimit, owner}: memory emptyDir added to the Pod (owner
                   must equal the policy identity); the workload becomes a bare Pod with a plan
  resources        merged into the container's resources (a memory tmpfs counts against the
                   memory limit)
Descriptor numbers follow the compiler's documented order: from 100 by volume name, then
projected path. They are computed before onboarding and checked against the bundle's
baked-volumes.json afterwards.

Environment (dev-prepare):
  SPTD_DEV_PREPARE     path to the sptd-dev-prepare binary (default: sptd-dev-prepare in PATH)
  SPTD_BUILD_SRC       scone-sptd-build checkout (for examples/clock/development-envcas)
  SPTD_SIGN_CMD        command run as: $SPTD_SIGN_CMD <oci-layout> <confidential-manifest>
  SPTD_PUSH            "false" to skip the registry push (preload instead)
"""
import argparse, base64, copy, hashlib, json, os, re, secrets, shlex, shutil, string, subprocess, sys, tarfile

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


# ---------------------------------------------------------------------------------------
# A8 route: sptd-hello-container-dev scone-dev-onboard/onboard.py
# ---------------------------------------------------------------------------------------

A8_REQUIRED_ENV = ("SPTD_ONBOARD", "SPTD_A8_TOOLS", "SPTD_DEV_SIGNING_KEY", "SPTD_DEV_ROOT_PIN")
A8_TOOLS = {"rootfs_build", "rootfs_verify", "compiler", "emitter", "signer", "cargo", "envcas_source"}
A8_OPTIONAL_TOOLS = {"memory_empty_dir"}
BAKE_FEATURE = "nonrelease-dev-baked-volumes"
FIRST_BAKED_DESCRIPTOR = 100


class Refused(Exception):
    """One container could not be onboarded; the message says why."""


def stream_digest(path):
    checksum = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            checksum.update(chunk)
    return "sha256:" + checksum.hexdigest()


def a8_settings():
    missing = [name for name in A8_REQUIRED_ENV if not os.environ.get(name)]
    if missing:
        raise SystemExit("SPTD_ROUTE=a8 needs " + ", ".join(missing) +
                         " (the signing key and root pin are never generated here)")
    pin = os.environ["SPTD_DEV_ROOT_PIN"]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", pin):
        raise SystemExit("SPTD_DEV_ROOT_PIN must be sha256:<64 hex>")
    tools = json.load(open(os.environ["SPTD_A8_TOOLS"]))
    if not A8_TOOLS <= set(tools) <= A8_TOOLS | A8_OPTIONAL_TOOLS:
        raise SystemExit("SPTD_A8_TOOLS must name exactly: " + ", ".join(sorted(A8_TOOLS)) +
                         " (and optionally " + ", ".join(sorted(A8_OPTIONAL_TOOLS)) + ")")
    assembly = os.environ.get("SPTD_A8_MEMORY_ASSEMBLY")
    if bool(assembly) != ("memory_empty_dir" in tools):
        raise SystemExit("SPTD_A8_MEMORY_ASSEMBLY and the memory_empty_dir tool are required together")
    layouts = {}
    if os.environ.get("SPTD_SOURCE_LAYOUTS"):
        layouts = json.load(open(os.environ["SPTD_SOURCE_LAYOUTS"]))
    here = os.path.dirname(os.path.abspath(__file__))
    return {"onboard": os.path.abspath(os.environ["SPTD_ONBOARD"]), "tools": tools,
            "key": os.path.abspath(os.environ["SPTD_DEV_SIGNING_KEY"]), "pin": pin,
            "cargo_target": os.environ.get("SPTD_A8_CARGO_TARGET"),
            "policies": os.path.abspath(os.environ.get("SPTD_POLICY_DIR", os.path.join(here, "policies"))),
            "layouts": layouts, "tag": os.environ.get("SPTD_A8_TAG", "sptd-dev"),
            "registry": os.environ.get("SPTD_A8_REGISTRY"),
            "memory_assembly": os.path.abspath(assembly) if assembly else None,
            "compiler_features": [f for f in os.environ.get("SPTD_A8_COMPILER_FEATURES", "").split(",") if f]}


def a8_overrides(settings, demo):
    """The demo's sptd-only overrides (<policies>/<demo>.overrides.json), keyed by workload name."""
    path = os.path.join(settings["policies"], f"{demo}.overrides.json")
    if not os.path.isfile(path):
        return {}
    value = json.load(open(path))
    if value.get("schema") != "sptd-demo-overrides-v1" or value.get("nonRelease") is not True:
        raise SystemExit(f"{path}: expected schema sptd-demo-overrides-v1 with nonRelease true")
    log(f"NON_RELEASE overrides {os.path.relpath(path, settings['policies'])} for "
        + ", ".join(sorted(value["workloads"])))
    return value["workloads"]


def with_overrides(doc, override):
    """A copy of the workload with the override's memory emptyDirs and resources applied."""
    doc = copy.deepcopy(doc)
    spec = pod_spec(doc)
    for name, item in (override or {}).get("containers", {}).items():
        container = next((c for c in spec.get("initContainers", []) + spec.get("containers", []) if c["name"] == name), None)
        if container is None:
            raise SystemExit(f"{doc['metadata']['name']}: override names unknown container {name}")
        for memory in item.get("memoryEmptyDirs", []):
            if any(v["name"] == memory["name"] for v in spec.get("volumes", [])):
                raise SystemExit(f"{doc['metadata']['name']}: override volume {memory['name']} already exists")
            spec.setdefault("volumes", []).append({"name": memory["name"],
                                                   "emptyDir": {"medium": "Memory", "sizeLimit": memory["sizeLimit"]}})
            container.setdefault("volumeMounts", []).append({"name": memory["name"], "mountPath": memory["mountPath"]})
        for section, values in item.get("resources", {}).items():
            container.setdefault("resources", {}).setdefault(section, {}).update(values)
        for env_name in item.get("removeEnv", []):
            before = len(container.get("env", []))
            container["env"] = [e for e in container.get("env", []) if e["name"] != env_name]
            if len(container["env"]) == before:
                raise SystemExit(f"{doc['metadata']['name']}: override removes unknown env {env_name}")
    return doc


def baked_sources(spec, container, selections):
    """[(volume name, mountPath, kind, object name, items)] of the selected ConfigMap/Secret volumes."""
    result = []
    for selection in selections:
        volume = next((v for v in spec.get("volumes", []) if v["name"] == selection["name"]), None)
        mount = [m for m in container.get("volumeMounts", []) if m["name"] == selection["name"]]
        if volume is None or len(mount) != 1 or not ({"configMap", "secret"} & set(volume)):
            raise Refused(f"baked volume {selection['name']} is not one mounted ConfigMap or Secret volume")
        kind = "ConfigMap" if "configMap" in volume else "Secret"
        source = volume["configMap"] if kind == "ConfigMap" else volume["secret"]
        result.append((selection["name"], mount[0]["mountPath"].rstrip("/"), kind,
                       source["name" if kind == "ConfigMap" else "secretName"], source.get("items")))
    return result


def open_path(descriptor):
    """The path a TD opens for a baked descriptor: /proc/self/fd/N, not the /dev/fd/N symlink.

    /dev/fd is itself a symlink in /dev; when the TD's /dev is a tmpfs, resolving it needs an
    lnk_file read the dev SELinux policy doesn't grant. /proc/self/fd/N avoids that hop.
    """
    prefix = "/dev/fd/"
    if not descriptor.startswith(prefix):
        raise Refused(f"unexpected baked descriptor {descriptor}")
    return "/proc/self/fd/" + descriptor[len(prefix):]


def baked_descriptors(sources, snapshots):
    """{original path: /dev/fd/N} in the compiler's documented order.

    rust-envcas scone-td-dev-compile (nonrelease-dev-baked-volumes) numbers the projected
    files from 100 in order of volume name and then projected path; with no items, every
    key is projected at its own name. Only names and paths enter the numbering, never
    values, so rewriting a baked value keeps every number.
    """
    paths = []
    for name, mount, kind, object_name, items in sorted(sources, key=lambda s: s[0].encode()):
        relative = [item["path"] for item in items] if items else list(snapshots[kind][object_name]["data"])
        paths += [f"{mount}/{path}" for path in sorted(relative, key=str.encode)]
    return {path: f"/dev/fd/{number}" for number, path in enumerate(paths, FIRST_BAKED_DESCRIPTOR)}


def rewrite_config(value, directives, descriptors):
    """Point each "<directive> <path>" line at the baked file's descriptor."""
    lines = []
    for line in value.splitlines(keepends=True):
        words = line.split()
        if len(words) == 2 and words[0] in directives:
            if words[1] not in descriptors:
                raise Refused(f"{words[0]} names {words[1]}, which is not a baked file")
            line = line.replace(words[1], open_path(descriptors[words[1]]), 1)
        lines.append(line)
    return "".join(lines)


def layout_to_archive(layout, archive):
    """Write an OCI layout directory as an oci-archive tar (regular files only, fixed metadata)."""
    names = ["oci-layout", "index.json"]
    for root, _, files in os.walk(os.path.join(layout, "blobs")):
        names += [os.path.relpath(os.path.join(root, f), layout) for f in files]
    with tarfile.open(archive, "w", format=tarfile.PAX_FORMAT) as tar:
        directories = sorted({os.path.dirname(n) for n in names if os.path.dirname(n)} |
                             {"blobs"})
        for name in directories + sorted(names):
            path = os.path.join(layout, name)
            info = tarfile.TarInfo(name)
            info.mtime, info.uid, info.gid, info.uname, info.gname = 0, 0, 0, "", ""
            if os.path.isdir(path):
                info.type, info.mode = tarfile.DIRTYPE, 0o755
                tar.addfile(info)
                continue
            info.size, info.mode = os.path.getsize(path), 0o644
            with open(path, "rb") as f:
                tar.addfile(info, f)


def archive_member(archive, name):
    with tarfile.open(archive, "r") as tar:
        for member in tar:
            if member.name.removeprefix("./") == name and member.isfile():
                return tar.extractfile(member).read()
    raise Refused(f"oci-archive has no {name}")


def image_symlinks(archive, wanted):
    """Symlink targets of `wanted` paths in the image's final filesystem (last layer wins).

    Reads the oci-archive's manifest and layer tars; whiteouts and later regular files
    replace an earlier symlink. Paths are absolute ("/config/x"); missing ones map to None.
    """
    import gzip, io
    index = json.loads(archive_member(archive, "index.json"))
    manifest = json.loads(archive_member(archive, "blobs/" + index["manifests"][0]["digest"].replace(":", "/")))
    state = {path: None for path in wanted}
    for layer in manifest["layers"]:
        blob = archive_member(archive, "blobs/" + layer["digest"].replace(":", "/"))
        if blob[:2] == b"\x1f\x8b":
            blob = gzip.decompress(blob)
        with tarfile.open(fileobj=io.BytesIO(blob), mode="r:") as tar:
            for member in tar:
                path = "/" + member.name.removeprefix("./").rstrip("/")
                base = os.path.basename(path)
                if base.startswith(".wh."):
                    removed = os.path.join(os.path.dirname(path), base[4:])
                    for key in state:
                        if key == removed or key.startswith(removed + "/"):
                            state[key] = None
                elif path in state:
                    state[path] = member.linkname if member.issym() else ("<not a symlink>")
    return state


def check_image_links(archive, links, descriptors):
    """NON_RELEASE: each image path must be a symlink to the baked descriptor of its source."""
    found = image_symlinks(archive, list(links))
    for path, source in links.items():
        if source not in descriptors:
            raise Refused(f"image link {path} names {source}, which is not a baked file")
        if found[path] != open_path(descriptors[source]):
            raise Refused(f"image link {path} is {found[path]!r}, expected a symlink to "
                          f"{open_path(descriptors[source])}")
    log("image links match the baked descriptors: "
        + ", ".join(f"{path} -> {open_path(descriptors[source])}" for path, source in links.items()))


def source_archive(image, settings, cwork):
    """Return (archive path, manifest digest, OCI config) for the source image."""
    archive = os.path.join(cwork, "source.oci.tar")
    if os.path.exists(archive):
        os.unlink(archive)
    local = settings["layouts"].get(image)
    if local and os.path.isdir(local):
        log(f"using local OCI layout {local} for {image}")
        layout_to_archive(local, archive)
    elif local:
        log(f"using local oci-archive {local} for {image}")
        shutil.copyfile(local, archive)
    elif os.environ.get("SPTD_A8_OFFLINE") == "true":
        raise Refused(f"{image} is not in SPTD_SOURCE_LAYOUTS and SPTD_A8_OFFLINE=true (no registry copy)")
    else:
        source = image if image.startswith("docker-daemon:") else f"docker://{image}"
        try:
            run(["skopeo", "copy", "--override-os", "linux", "--override-arch", "amd64",
                 source, f"oci-archive:{archive}:source"])
        except (OSError, subprocess.CalledProcessError) as error:
            raise Refused(f"skopeo copy of {image} failed: {error}")
    index = json.loads(archive_member(archive, "index.json"))
    manifests = index.get("manifests", [])
    if len(manifests) != 1:
        raise Refused(f"{image}: expected one manifest in the OCI archive, got {len(manifests)}")
    digest = manifests[0]["digest"]
    manifest = json.loads(archive_member(archive, "blobs/sha256/" + digest.split(":", 1)[1]))
    config = json.loads(archive_member(archive, "blobs/sha256/" + manifest["config"]["digest"].split(":", 1)[1]))
    return archive, digest, config


def a8_repository(target):
    """Registry repository spelling for the profile registry: no docker.io/, no port, lowercase."""
    repo = image_repository(target)
    repo = repo.removeprefix("docker.io/")
    if re.fullmatch(r"[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*", repo) and len(repo) <= 255:
        return repo
    raise Refused(f"output-image repository {repo!r} is not a valid profile-registry repository "
                  "(lowercase path, no port)")


def dns_label(text):
    label = re.sub(r"[^a-z0-9-]+", "-", text.lower()).strip("-")[:63].strip("-")
    if not label:
        raise Refused(f"cannot derive a profile id from {text!r}")
    return label


def effective_argv0(container, config):
    """Kubernetes command/args over OCI Entrypoint/Cmd, as the owner compiler resolves them."""
    image = config.get("config", {})
    if container.get("command"):
        return container["command"][0]
    entrypoint = image.get("Entrypoint") or []
    if entrypoint:
        return entrypoint[0]
    command = container.get("args") or image.get("Cmd") or []
    if not command:
        raise Refused("no command: neither the Pod nor the image config names an executable")
    return command[0]


def cmd_only_command(container, config):
    """Cmd of a Cmd-only image when the Pod sets neither command nor args, else None.

    Kubernetes runs such a container as exactly Cmd, the same as `command: <Cmd>`.
    rust-envcas scone-td-dev-compile before #46 (for example c61cf4e) passed only the
    Entrypoint part as the command to the environment compiler, which refused it as an
    "empty effective command". The pinned rust-envcas main (f69a0a61, see
    docs/sptd-mode.md) runs Cmd itself; the explicit command stays so that the
    onboarding request and argv are the same with either compiler.
    """
    image = config.get("config", {})
    if container.get("command") or container.get("args") or image.get("Entrypoint") or not image.get("Cmd"):
        return None
    return list(image["Cmd"])


def a8_pod(doc, container, image_ref, command=None):
    """One Pod for the compiler: the workload's Pod template with this container pinned."""
    template = doc["spec"]["template"] if doc["kind"] != "Pod" else doc
    if doc["kind"] == "CronJob":
        template = doc["spec"]["jobTemplate"]["spec"]["template"]
    meta = template.get("metadata", {}) if doc["kind"] != "Pod" else doc.get("metadata", {})
    spec = copy.deepcopy(pod_spec(doc))
    spec["automountServiceAccountToken"] = False
    spec["enableServiceLinks"] = False
    for item in spec.get("containers", []) + spec.get("initContainers", []):
        if item["name"] == container["name"]:
            item["image"] = image_ref
            if command:
                item["command"] = command
    pod = {"apiVersion": "v1", "kind": "Pod",
           "metadata": {"name": doc["metadata"]["name"],
                        "namespace": doc["metadata"].get("namespace", "default")},
           "spec": spec}
    if meta.get("labels"):
        pod["metadata"]["labels"] = meta["labels"]
    return pod


def referenced_objects(container):
    configmaps, secrets = set(), set()
    for item in container.get("envFrom", []):
        if "configMapRef" in item:
            configmaps.add(item["configMapRef"]["name"])
        if "secretRef" in item:
            secrets.add(item["secretRef"]["name"])
    for item in container.get("env", []):
        source = item.get("valueFrom", {})
        if "configMapKeyRef" in source:
            configmaps.add(source["configMapKeyRef"]["name"])
        if "secretKeyRef" in source:
            secrets.add(source["secretKeyRef"]["name"])
    return configmaps, secrets


def scone_secret(doc):
    """A SconeSecret (CAS-generated values) as an offline Secret snapshot.

    Only `valueGenerated: {kind: ascii, size: N}` is supported: the value is generated
    here, compiled into a sealed payload of the launcher and never written to the output
    manifest. Each run generates a new value.
    """
    data = {}
    for key, spec in (doc.get("data") or {}).items():
        generated = (spec or {}).get("valueGenerated") if isinstance(spec, dict) else None
        if not generated or generated.get("kind") != "ascii" or not isinstance(generated.get("size"), int) \
                or not 0 < generated["size"] <= 4096:
            raise Refused(f"SconeSecret {doc['metadata']['name']}/{key}: only valueGenerated kind ascii is supported")
        alphabet = string.ascii_letters + string.digits
        data[key] = base64.b64encode("".join(secrets.choice(alphabet) for _ in range(generated["size"])).encode()).decode()
    return {"apiVersion": "v1", "kind": "Secret", "metadata": dict(doc["metadata"]), "data": data}


def snapshot(doc, secret):
    data = dict(doc.get("data") or {})
    if secret:
        try:
            data = {k: base64.b64decode(v).decode() for k, v in data.items()}
        except (ValueError, UnicodeDecodeError):
            raise Refused(f"Secret {doc['metadata']['name']} has non-UTF-8 data")
        data.update(doc.get("stringData") or {})
    name = doc["metadata"]["name"]
    return {"name": name, "uid": f"sptd-offline-{name}", "resourceVersion": "1",
            "data": {k: str(v) for k, v in data.items()}}


def a8_policy(settings, demo, profile, container):
    """Per-demo template if present, else the generic one; contract and role ids filled in."""
    for name in (demo, "generic"):
        path = os.path.join(settings["policies"], f"{name}.json")
        if os.path.isfile(path):
            break
    policy = json.load(open(path))
    policy["metadata"]["contractId"] = f"sptd-demos/{profile}:application"
    policy["role"] = {"kind": "application", "name": container["name"], "casRole": "scone/" + profile}
    endpoints = None
    path_endpoints = os.path.join(settings["policies"], f"{demo}.endpoints.json")
    if os.path.isfile(path_endpoints):
        endpoints = json.load(open(path_endpoints)).get(container["name"])
    return policy, os.path.relpath(path, settings["policies"]), endpoints


def write_json(path, value):
    with open(path, "w") as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write("\n")
    return path


def a8_diagnose(settings, request, cwork):
    """onboard.py hides owner-tool errors. Re-run the stages up to the profile emitter with
    their own fixed, value-free diagnostics, and return the first refusal."""
    tools = settings["tools"]
    diag = os.path.join(cwork, "diagnose")
    if os.path.exists(diag):
        shutil.rmtree(diag)
    os.makedirs(diag, mode=0o700)

    def stage(name, cmd, **kw):
        result = subprocess.run([str(c) for c in cmd], capture_output=True, **kw)
        if result.returncode:
            text = (result.stderr or result.stdout).decode(errors="replace").strip().splitlines()
            raise Refused(f"{name}: " + (text[-1] if text else f"rc={result.returncode}"))
        return result.stdout

    try:
        cache = os.path.join(diag, "rootfs-cache")
        with open(request["archive"], "rb") as stream:
            built = json.loads(stage("rootfs build", [tools["rootfs_build"], "--offline", "--reproducible", "--stdin",
                                     "--digest", request["archive_sha256"], "--platform", "linux/amd64",
                                     "--limit", request["archive_limit"], "--cache", cache], stdin=stream))
        artifact = built["digest"]
        record = json.load(open(os.path.join(cache, "records", artifact.split(":", 1)[1] + ".json")))
        stage("rootfs verify", [tools["rootfs_verify"], "--cache", cache, "--digest", artifact,
                                "--root-hash", record["root_hash"]])
        manifest = record["manifest"]["digest"]
        facts = json.loads(stage("rootfs facts (executable)", [tools["emitter"], "rootfs-facts",
                                 os.path.join(cache, "objects", manifest.split(":", 1)[1]), manifest,
                                 request["executable"]]))
        facts["artifactDigest"] = artifact
        config = os.path.join(diag, "config.json")
        open(config, "wb").write(archive_member(request["archive"], "blobs/sha256/" + facts["configDigest"].split(":", 1)[1]))
        if "baked_volumes" in request or "memory_empty_dir_assembly" in request:
            return ("stages up to rootfs facts pass; this diagnosis does not replay baked-volume or "
                    "memory emptyDir receipts")
        compiled = os.path.join(diag, "compiled")
        os.makedirs(compiled, mode=0o700)
        compile_request = dict(request.get("snapshots", {}), pod=request["pod"], policy=request["policy"],
                               policySha256=request["policy_sha256"], config=config, facts=facts,
                               workload=request["workload"], profileId=request["profile_id"])
        if request.get("role_only"):
            compile_request["roleOnly"] = True
        stage("compiler", [tools["compiler"], write_json(os.path.join(diag, "compile.json"), compile_request), compiled])
        authority = os.path.join(compiled, "authority.json")
        args = [tools["emitter"], "emit-profile", request["pod"], authority, stream_digest(authority),
                os.path.join(compiled, "contract.json"), facts["configDigest"], os.path.join(diag, "profile")]
        if "endpoints" in request:
            args += ["--endpoints", request["endpoints"]]
        if request.get("role_only"):
            args += ["--role-only"]
        stage("profile emitter", args)
        return "stages up to the profile emitter pass; the refusal is in sealing, signing or the registry"
    except Refused as error:
        return str(error)
    finally:
        shutil.rmtree(diag, ignore_errors=True)


def a8_check_bundle(settings, bundle):
    """Re-check a published bundle: every checksum, the signed profile against the root pin."""
    report = json.load(open(os.path.join(bundle, "bundle.json")))
    if report.get("runtimeReady") is not False or report.get("rootPin") != settings["pin"]:
        raise Refused("bundle report is not a runtimeReady:false bundle for this root pin")
    checksums = json.load(open(os.path.join(bundle, "checksums.json")))
    for relative, expected in checksums.items():
        if stream_digest(os.path.join(bundle, relative)) != expected:
            raise Refused(f"bundle checksum mismatch: {relative}")
    profile = os.path.join(bundle, "profile")
    verified = subprocess.run([settings["tools"]["emitter"], "verify-profile", os.path.join(profile, "profile.cbor"),
                               os.path.join(profile, "profile.sig"), os.path.join(profile, "root.spki.der"),
                               settings["pin"], report["imageConfigDigest"]], capture_output=True)
    if verified.returncode:
        raise Refused("signed profile does not verify against SPTD_DEV_ROOT_PIN")
    return report


def a8_container(settings, demo, doc, container, image, target, objects, work, registry, role_only=False,
                 override=None):
    """Onboard one container. Returns (bundle dir, contract image reference, report, explicit command,
    baked volume names)."""
    override = override or {}
    name = f"{doc['metadata']['name']}-{container['name']}"
    profile = dns_label(name if doc["metadata"]["name"] != container["name"] else container["name"])
    cwork = os.path.join(work, "a8", demo, doc["metadata"]["name"], container["name"])
    os.makedirs(cwork, mode=0o700, exist_ok=True)
    os.chmod(cwork, 0o700)
    repository = a8_repository(target)
    archive, manifest_digest, config = source_archive(image, settings, cwork)
    image_ref = f"{repository}@{manifest_digest}"
    selections = override.get("bakedVolumes", [])
    baked = {"ConfigMap": {}, "Secret": {}}
    descriptors = {}
    if selections:
        if BAKE_FEATURE not in settings["compiler_features"]:
            raise Refused(f"baked volumes need a compiler built with {BAKE_FEATURE} "
                          "(SPTD_A8_COMPILER_FEATURES)")
        sources = baked_sources(pod_spec(doc), container, selections)
        for _, _, kind, object_name, _ in sources:
            if object_name not in objects[kind]:
                raise Refused(f"baked {kind} {object_name} is not in the Apply files")
            baked[kind][object_name] = snapshot(objects[kind][object_name], kind == "Secret")
        descriptors = baked_descriptors(sources, baked)
        for rewrite in override.get("configRewrites", []):
            data = baked["ConfigMap"].get(rewrite["configMap"], {}).get("data", {})
            if rewrite["key"] not in data:
                raise Refused(f"config rewrite names {rewrite['configMap']}/{rewrite['key']}, which is not baked")
            data[rewrite["key"]] = rewrite_config(data[rewrite["key"]], set(rewrite["directives"]), descriptors)
        log(f"{name}: NON_RELEASE baked volumes {', '.join(s['name'] for s in selections)}: "
            + ", ".join(f"{path} -> {fd}" for path, fd in descriptors.items()))
        if override.get("imageLinks"):
            check_image_links(archive, override["imageLinks"], descriptors)
    if "command" in override:
        try:
            command = [open_path(descriptors[arg["descriptor"]]) if isinstance(arg, dict) else arg
                       for arg in override["command"]]
        except KeyError as error:
            raise Refused(f"override command names {error}, which is not a baked file")
        log(f"{name}: override command {command}")
    else:
        command = cmd_only_command(container, config)
        if command:
            log(f"{name}: Cmd-only image; using its Cmd as the explicit command {command}")
    pod = a8_pod(doc, container, image_ref, command)
    argv0 = effective_argv0(dict(container, command=command) if command else container, config)
    if not argv0.startswith("/"):
        raise Refused(f"argv[0] {argv0!r} is not an absolute path (set an absolute command)")
    policy, policy_name, endpoints = a8_policy(settings, demo, profile, container)
    configmaps, secrets = referenced_objects(container)
    missing = sorted((configmaps - set(objects["ConfigMap"])) | (secrets - set(objects["Secret"])))
    if missing:
        raise Refused("env references objects that are not in the Apply files: " + ", ".join(missing))
    snapshots = {"ConfigMap": {n: snapshot(objects["ConfigMap"][n], False) for n in configmaps},
                 "Secret": {n: snapshot(objects["Secret"][n], True) for n in secrets}}
    for kind in snapshots:
        snapshots[kind].update(baked[kind])
    mounted = {m["name"] for m in container.get("volumeMounts", [])}
    memory = [v for v in pod["spec"].get("volumes", [])
              if (v.get("emptyDir") or {}).get("medium") == "Memory" and v["name"] in mounted]
    identity = policy["process"]["identity"]
    for item in override.get("memoryEmptyDirs", []):
        if item.get("owner") != {"uid": identity["uid"], "gid": identity["gid"]}:
            raise Refused(f"memory emptyDir {item['name']} owner differs from the policy identity")
    tools = {k: v for k, v in settings["tools"].items() if k in A8_TOOLS or (memory and k == "memory_empty_dir")}
    if memory and "memory_empty_dir" not in tools:
        raise Refused("memory emptyDir needs SPTD_A8_MEMORY_ASSEMBLY and the memory_empty_dir tool")
    request = {
        "schema": "scone-dev-onboard-request-v1",
        "archive": archive, "archive_sha256": stream_digest(archive),
        "archive_limit": max(512 * 1024 ** 2, os.path.getsize(archive) + 1),
        "pod": write_json(os.path.join(cwork, "pod.json"), pod),
        "policy": write_json(os.path.join(cwork, "policy.json"), policy),
        "executable": argv0, "profile_id": profile,
        "workload": {"namespace": pod["metadata"]["namespace"], "podName": pod["metadata"]["name"],
                     "podUid": f"sptd-offline-{profile}", "containerName": container["name"],
                     "serviceAccountName": pod["spec"].get("serviceAccountName", "default")},
        # The registry keys preload entries by (repository, tag); one tag per profile keeps
        # several containers of one repository (network-policy client/server) apart.
        "registry_entry": {"profile": profile, "repository": repository, "tag": f"{settings['tag']}-{profile}"[:128],
                           "config_id": "scone/" + profile},
        "signing_key": settings["key"], "root_pin": settings["pin"],
        "tools": tools,
        "snapshots": {"configMaps": [snapshots["ConfigMap"][n] for n in sorted(snapshots["ConfigMap"])],
                      "secrets": [snapshots["Secret"][n] for n in sorted(snapshots["Secret"])],
                      "payloads": []},
    }
    if selections:
        request["baked_volumes"] = selections
        request["compiler_features"] = [BAKE_FEATURE]
    if memory:
        request["memory_empty_dir_assembly"] = settings["memory_assembly"]
        request["memory_empty_dir_assembly_sha256"] = stream_digest(settings["memory_assembly"])
        log(f"{name}: memory emptyDir {', '.join(v['name'] for v in memory)} (NON_RELEASE receipt, key 4)")
    request["policy_sha256"] = stream_digest(request["policy"])
    if settings["cargo_target"]:
        request["cargo_target"] = os.path.abspath(settings["cargo_target"])
    if endpoints:
        request["endpoints"] = write_json(os.path.join(cwork, "endpoints.json"), endpoints)
    if role_only:
        request["role_only"] = True
        log(f"{name}: role-only bundle for a signed Pod plan")
    if registry:
        request["registry"] = registry
    request_path = write_json(os.path.join(cwork, "request.json"), request)
    bundle = os.path.join(cwork, "bundle")
    if os.path.exists(bundle):
        shutil.rmtree(bundle)
    log(f"{name}: onboarding {image} ({manifest_digest}) with policy {policy_name}, executable {argv0}")
    result = subprocess.run([sys.executable, settings["onboard"], request_path, bundle],
                            capture_output=True, text=True)
    try:
        if result.returncode:
            refusal = (result.stderr or result.stdout).strip()
            raise Refused(f"{refusal}; first stage refusal: {a8_diagnose(settings, request, cwork)}")
        report = a8_check_bundle(settings, bundle)
        if selections:
            mapping = json.load(open(os.path.join(bundle, "baked-volumes.json")))
            found = {item["path"]: item["descriptor"] for item in mapping["files"]}
            if found != descriptors:
                raise Refused(f"bundle descriptor mapping {found} differs from the documented order {descriptors}")
    finally:
        os.unlink(archive)
        # Keep the request for debugging, without the snapshot values (Secrets, generated values).
        for kind in ("configMaps", "secrets"):
            for item in request["snapshots"][kind]:
                item["data"] = {k: "<redacted>" for k in item["data"]}
        write_json(request_path, request)
    contract = json.load(open(os.path.join(bundle, "contract.json")))
    return bundle, contract["image"]["reference"], report, command, {s["name"] for s in selections}


def a8_rewrite(doc, container_name, bundle):
    """Apply the bundle's KCT-023 rewritten container to the workload's Pod template.

    The rewritten container starts /usr/local/bin/envcas-rs `activate` with the signed
    contract/policy/role/profile IDs; env and envFrom are compiled into the sealed launcher
    and removed. Its role annotations go onto the Pod template. A role-only bundle (several
    containers in one Pod) has no rewritten workload: deployment needs a signed Pod plan.
    """
    rewritten = json.load(open(os.path.join(bundle, "profile", "workload.json")))
    if rewritten.get("requiresSignedPodPlan"):
        raise Refused("role-only bundle: the Pod has several containers and needs a signed Pod plan "
                      "(scone-dev-onboard/pod_plan.py); no output manifest can be written")
    spec = pod_spec(doc)
    spec["automountServiceAccountToken"] = False
    spec["enableServiceLinks"] = False
    source = next(c for c in rewritten["spec"]["containers"] if c["name"] == container_name)
    for index, item in enumerate(spec.get("containers", [])):
        if item["name"] == container_name:
            item = copy.deepcopy(source)
            item["imagePullPolicy"] = "Never"  # preloaded from the bundle, never pulled
            spec["containers"][index] = item
    template = doc if doc["kind"] == "Pod" else (doc["spec"]["jobTemplate"]["spec"]["template"]
                                                 if doc["kind"] == "CronJob" else doc["spec"]["template"])
    annotations = template.setdefault("metadata", {}).setdefault("annotations", {})
    annotations.update(rewritten.get("metadata", {}).get("annotations", {}))


def needs_pod_plan(doc):
    """A signed Pod plan (pod_plan.py) is needed for a multi-role Pod (init containers plus
    applications, or more than one container) or a memory emptyDir. Single-container Pods
    run with the signed registry alone and stay Jobs/Deployments."""
    spec = pod_spec(doc)
    roles = len(spec.get("containers", [])) + len(spec.get("initContainers", []))
    memory = any((v.get("emptyDir") or {}).get("medium") == "Memory" for v in spec.get("volumes", []))
    reasons = (["multi-role Pod"] if roles > 1 else []) + (["memory emptyDir"] if memory else [])
    return reasons


def a8_plan_pod(settings, demo, doc, bundles, work):
    """Build and sign the Pod plan; return the bare Pod (kind Pod, fixed name) to apply.

    The plan binds namespace, pod_name and the canonical Pod spec, so the node shaping
    (RuntimeClass, hostNetwork, nodeName, toleration) goes into the source Pod and the
    plan's projected spec is written unchanged.
    """
    pod = a8_pod(doc, {"name": None}, None)  # labels kept, so Services still select the Pod
    spec = pod["spec"]
    spec.setdefault("restartPolicy", "Always")
    baked = set()
    for item in spec.get("initContainers", []) + spec.get("containers", []):
        bundle, image_ref, command, names = bundles[item["name"]]
        item["image"] = image_ref
        item["imagePullPolicy"] = "Never"
        if command:
            item["command"] = command
        if names:
            # The role was compiled against the transformed Pod: the baked files are sealed
            # descriptors, so neither the plan nor the bare Pod declares these volumes.
            item["volumeMounts"] = [m for m in item.get("volumeMounts", []) if m["name"] not in names]
            if not item["volumeMounts"]:
                del item["volumeMounts"]
            baked |= names
    if baked:
        spec["volumes"] = [v for v in spec.get("volumes", []) if v["name"] not in baked]
        if not spec["volumes"]:
            del spec["volumes"]
    shape_for_node(pod)
    pwork = os.path.join(work, "a8", demo, doc["metadata"]["name"], ".pod-plan")
    if os.path.exists(pwork):
        shutil.rmtree(pwork)
    os.makedirs(pwork, mode=0o700)
    source = write_json(os.path.join(pwork, "pod.json"), pod)
    roles = [{"name": item["name"], "bundle": bundles[item["name"]][0],
              "checksums_sha256": stream_digest(os.path.join(bundles[item["name"]][0], "checksums.json"))}
             for item in spec.get("initContainers", []) + spec.get("containers", [])]
    request = write_json(os.path.join(pwork, "request.json"), {
        "schema": "scone-dev-pod-plan-request-v1", "pod": source, "pod_sha256": stream_digest(source),
        "profile_id": dns_label(doc["metadata"]["name"]), "roles": roles,
        "emitter": settings["tools"]["emitter"], "signing_key": settings["key"], "root_pin": settings["pin"]})
    plan_dir = os.path.join(pwork, "plan")
    tool = os.path.join(os.path.dirname(settings["onboard"]), "pod_plan.py")
    result = subprocess.run([sys.executable, tool, request, plan_dir], capture_output=True, text=True)
    if result.returncode:
        raise Refused("pod_plan.py: " + ((result.stderr or result.stdout).strip().splitlines() or ["refused"])[-1])
    workload = json.load(open(os.path.join(plan_dir, "workload.json")))
    # Collect the plans of a run in one directory (the node reads 1-64 signed plans), one plan
    # per bare Pod, plus the request without key and pin so it can be re-signed elsewhere.
    # The role bundles are signed with the same key: re-signing for another root means
    # onboarding the roles again with that root.
    plans = os.path.join(work, "a8", "pod-plans")
    os.makedirs(plans, exist_ok=True)
    stem = f"{pod['metadata']['namespace']}_{pod['metadata']['name']}"
    for suffix in ("", ".sig", ".root.pem"):
        shutil.copyfile(os.path.join(plan_dir, "pod-plan.json" + suffix), os.path.join(plans, f"{stem}.pod-plan.json{suffix}"))
    unsigned = json.load(open(request))
    unsigned.update(signing_key="<dev root signing key path>", root_pin="<sha256: root pin of that key>")
    write_json(os.path.join(plans, f"{stem}.pod-plan-request.unsigned.json"), unsigned)
    log(f"{doc['metadata']['name']}: signed Pod plan {plans}/{stem}.pod-plan.json")
    return {"apiVersion": "v1", "kind": "Pod", "metadata": workload["metadata"], "spec": workload["spec"]}, plan_dir


def a8_workload(settings, demo, doc, images, base, objects, work, registry, overrides=None):
    """Onboard every registered role of one workload. Returns (output doc, entries, refused, registry)."""
    override = (overrides or {}).get(doc["metadata"]["name"])
    if override:
        doc = with_overrides(doc, override)
    plan = needs_pod_plan(doc)
    spec = pod_spec(doc)
    result = copy.deepcopy(doc)
    entries, refused, bundles = [], 0, {}
    if plan:
        log(f"{doc['metadata']['name']}: {', '.join(plan)}: role-only bundles and a signed Pod plan; "
            "the output is a bare Pod")
    for container in spec.get("initContainers", []) + spec.get("containers", []):
        if container["image"] not in images:
            log(f"{doc['metadata']['name']}/{container['name']}: image {container['image']} "
                "is not registered in scone.yaml; left unchanged")
            if plan:
                refused += 1
                entries.append({"demo": demo, "workload": f"{doc['kind']}/{doc['metadata']['name']}",
                                "container": container["name"], "result": "REFUSED",
                                "refusal": "a Pod plan needs every role onboarded; this image is not registered"})
            continue
        source = sptd_source_image(base, container["image"])
        entry = {"demo": demo, "workload": f"{doc['kind']}/{doc['metadata']['name']}",
                 "container": container["name"], "source": source, "podPlan": plan or None}
        try:
            bundle, image_ref, report, command, baked = a8_container(
                settings, demo, doc, container, source, images[container["image"]], objects, work,
                registry, role_only=bool(plan), override=(override or {}).get("containers", {}).get(container["name"]))
            registry = os.path.join(bundle, "profile-registry.json")
            if not plan:
                a8_rewrite(result, container["name"], bundle)
        except Refused as error:
            refused += 1
            entry.update(result="REFUSED", refusal=str(error))
            log(f"{doc['metadata']['name']}/{container['name']}: REFUSED: {error}")
        else:
            bundles[container["name"]] = (bundle, image_ref, command, baked)
            entry.update(result="PASS", bundle=bundle, image=image_ref, registry=registry,
                         roleOnly=report.get("requiresSignedPodPlan", False),
                         profileDigest=report["profileDigest"], contractDigest=report["contractDigest"],
                         artifactDigest=report["artifactDigest"], launcherFeatures=report.get("launcherFeatures"),
                         providerAdmissionRefusal=report.get("providerAdmissionRefusal"),
                         bakedDescriptors=report.get("bakedDescriptors"),
                         memoryEmptyDirDeclared=report.get("memoryEmptyDirDeclared", False))
            log(f"{doc['metadata']['name']}/{container['name']}: PASS: bundle {bundle} "
                "(offline preload bundle, runtimeReady false)")
        entries.append(entry)
    if plan and not refused and bundles:
        try:
            result, plan_dir = a8_plan_pod(settings, demo, doc, bundles, work)
            for entry in entries:
                entry["podPlan"] = os.path.join(plan_dir, "pod-plan.json")
        except Refused as error:
            refused += 1
            entries.append({"demo": demo, "workload": f"{doc['kind']}/{doc['metadata']['name']}",
                            "container": "(Pod plan)", "result": "REFUSED", "refusal": str(error)})
            log(f"{doc['metadata']['name']}: Pod plan REFUSED: {error}")
    elif bundles:
        shape_for_node(result)
    return result, entries, refused, registry


def demo_name(scone_yaml):
    """Top-level demo directory of scone.yaml (the policy file name)."""
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    relative = os.path.relpath(os.path.abspath(scone_yaml), root)
    return relative.split(os.sep, 1)[0] if os.sep in relative else "generic"


def shape_for_node(doc):
    pod = pod_spec(doc)
    pod["runtimeClassName"] = os.environ.get("SPTD_RUNTIME_CLASS", "scone-dev")
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

    Never builds when the source image is already supplied as a layout
    (SPTD_SOURCE_LAYOUTS) or when SPTD_A8_OFFLINE=true: offline runs must not start
    docker builds or touch registry credentials.
    """
    if os.environ.get("SPTD_SOURCE_LAYOUTS"):
        if image in json.load(open(os.environ["SPTD_SOURCE_LAYOUTS"])):
            return image
    if os.environ.get("SPTD_A8_OFFLINE") == "true":
        return image
    directory, root = base, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    root = os.path.dirname(root)  # repository root (scripts/sptd/.. /..)
    # sptd-mode images kept outside the demo directories, built with the demo as context:
    # scripts/sptd/images/<demo>/Dockerfile (for example native-image or baked-file symlinks).
    relative = os.path.relpath(os.path.abspath(base), root)
    demo = relative.split(os.sep, 1)[0] if not relative.startswith("..") else None
    dockerfile = os.path.join(root, "scripts", "sptd", "images", demo or "-", "Dockerfile")
    if demo and os.path.isfile(dockerfile):
        directory = os.path.join(root, demo)
    else:
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


def dev_lint(path, docs):
    """Optional NON_RELEASE pre-flight lint (scone-sptd-build sptd-dev-lint, JSON scone-dev-lint-v1).

    Exit 0 clean, 3 findings (stop and list them), 2 usage error, 1 internal error.
    """
    lint = os.environ.get("SPTD_DEV_LINT")
    if not lint:
        return
    controllers = any(d.get("kind") in WORKLOAD_PODS and d.get("kind") != "Pod" for d in docs)
    cmd = [lint, "--path", "offline" if controllers else "canonical", path]
    log("+ " + " ".join(shlex.quote(c) for c in cmd))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        log(f"sptd-dev-lint: {os.path.basename(path)} clean")
        return
    if result.returncode == 3:
        try:
            report = json.loads(result.stdout)
            findings = report.get("findings", report)
        except json.JSONDecodeError:
            findings = result.stdout.strip()
        if isinstance(findings, list):
            text = "\n".join("  - " + (json.dumps(f, sort_keys=True) if not isinstance(f, str) else f) for f in findings)
        else:
            text = "  " + (findings if isinstance(findings, str) else json.dumps(findings, sort_keys=True))
        raise SystemExit(f"sptd-dev-lint found problems in {path}:\n{text}")
    raise SystemExit(f"sptd-dev-lint failed on {path} (rc={result.returncode}): {result.stderr.strip()}")


def apply_base(scone_yaml, applies):
    """Directory the Apply file paths are relative to.

    The READMEs run `scone-td-build apply -f manifests/scone.yaml` from the demo directory
    with paths such as manifests/manifest.yaml, so paths are relative to the working
    directory. Fall back to the scone.yaml directory when they do not resolve there.
    """
    files = [f for spec in applies for f in (spec["file"] if isinstance(spec["file"], list) else [spec["file"]])]
    if all(os.path.isfile(f) for f in files):
        return os.getcwd()
    return os.path.dirname(os.path.abspath(scone_yaml))


def apply(scone_yaml):
    # A demo may ship an sptd-only scone variant too, for example one Register per image.
    directory = os.path.dirname(scone_yaml) or "."
    scone_yaml = os.path.join(directory, sptd_variant(directory, os.path.basename(scone_yaml)))
    docs = load_yaml_docs(scone_yaml)
    registers = [d["spec"] for d in docs if d.get("kind") == "Register"]
    applies = [d["spec"] for d in docs if d.get("kind") == "Apply"]
    if not applies:
        raise SystemExit(f"{scone_yaml}: no Apply document")
    base = apply_base(scone_yaml, applies)
    images = {r["source-image"]: r.get("output-image") or r["source-image"] for r in registers}
    route = os.environ.get("SPTD_ROUTE", "a8")
    if route == "a8":
        settings, tool = a8_settings(), None
        overrides = a8_overrides(settings, demo_name(scone_yaml))
        registry = os.path.abspath(settings["registry"]) if settings["registry"] else None
        log("route a8: offline onboarding (onboard.py), preload bundles, runtimeReady false")
    elif route == "dev-prepare":
        tool = os.environ.get("SPTD_DEV_PREPARE") or shutil.which("sptd-dev-prepare")
        if not tool:
            raise SystemExit("sptd-dev-prepare not found (set SPTD_DEV_PREPARE)")
    else:
        raise SystemExit(f"SPTD_ROUTE must be a8 or dev-prepare, got {route!r}")
    demo = demo_name(scone_yaml)
    work = os.path.abspath(os.environ.get("SPTD_WORK_DIR", ".sptd-work"))
    os.makedirs(work, exist_ok=True)
    results, refused = [], 0
    for spec in applies:
        files = spec["file"] if isinstance(spec["file"], list) else [spec["file"]]
        files = [sptd_variant(base, f) for f in files]
        for f in files:
            dev_lint(os.path.join(base, f), load_yaml_docs(os.path.join(base, f)))
        inputs = [d for f in files for d in load_yaml_docs(os.path.join(base, f))]
        configmaps = {d["metadata"]["name"]: d for d in inputs if d.get("kind") == "ConfigMap"}
        objects = {"ConfigMap": configmaps,
                   "Secret": {d["metadata"]["name"]: d for d in inputs if d.get("kind") == "Secret"}}
        scone_secrets = [d for d in inputs if d.get("kind") == "SconeSecret"]
        output = []
        if route == "a8":
            try:
                objects["Secret"].update({d["metadata"]["name"]: scone_secret(d) for d in scone_secrets})
            except Refused as error:
                raise SystemExit(str(error))
            # Consumed into the sealed launchers; there is no SconeSecret kind in the cluster.
            inputs = [d for d in inputs if d.get("kind") != "SconeSecret"]
        for doc in inputs:
            if doc.get("kind") not in WORKLOAD_PODS:
                output.append(doc)
                continue
            if route == "a8":
                result, entries, count, registry = a8_workload(settings, demo, doc, images, base, objects,
                                                               work, registry, overrides)
                results += entries
                refused += count
                output.append(result)
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
        if route == "a8":
            summary = write_json(os.path.join(work, "a8", f"{demo}.summary.json"),
                                 {"demo": demo, "scone_yaml": os.path.abspath(scone_yaml), "results": results,
                                  "registry": registry})
            log(f"summary: {summary}")
            if refused:
                raise SystemExit(f"{refused} container(s) refused; {spec['output-manifest']} not written")
        target = os.path.join(base, spec["output-manifest"])
        with open(target, "w") as f:
            yaml.safe_dump_all(output, f, sort_keys=False)
        log(f"wrote {spec['output-manifest']} (development only: CAS bypassed)")
        if route == "a8":
            log(f"preload every bundle and the signed registry {registry} on the node before applying it")


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
