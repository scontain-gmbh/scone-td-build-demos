#!/usr/bin/env python3
"""Validate an sptd demo artifact-set manifest (artifact-manifest.schema.json). NON_RELEASE.

  artifact_manifest.py validate MANIFEST [--set DIR] [--facts FACTS] [--expect-hash sha256:...]
                                [--require-complete] [--deep] [--allow-stand-in] [--no-files]
  artifact_manifest.py hash MANIFEST        print the recomputed artifact-set hash

Checks, in order: the pinned schema; the artifact-set hash; the catalog order and phases;
the registry (append-only history, profile names, every role's profile listed once);
the Pod plans (unique names and namespace/pod, every referenced plan present); the
landed-image facts (when given); every pinned file's digest (unless --no-files); with
--deep every bundle file against its checksums.json; and that no file of the set holds
PEM private-key material. Exit 0 when valid, 1 otherwise.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sptdinteg as si  # noqa: E402

PRIVATE_KEY_MARKERS = (b"PRIVATE KEY-----", b"OPENSSH PRIVATE KEY")
SCAN_LIMIT = 4 * 1024 * 1024


def validate(manifest, set_dir=None, facts=None, facts_path=None, expect_hash=None, require_complete=False,
             deep=False, allow_stand_in=False, catalog=None):
    """Raise si.Invalid with every problem found; return a short summary dict when valid."""
    si.check_schema(manifest, si.MANIFEST_SCHEMA, "manifest")
    problems = []
    computed = si.artifact_set_sha256(manifest)
    if computed != manifest["artifactSetSha256"]:
        problems.append(f"artifactSetSha256 is {manifest['artifactSetSha256']}, recomputed {computed}")
    if expect_hash and expect_hash != manifest["artifactSetSha256"]:
        problems.append(f"artifact set is {manifest['artifactSetSha256']}, expected {expect_hash}")
    if manifest["facts"]["standIn"] and not allow_stand_in:
        problems.append("the set was built from stand-in facts (pass --allow-stand-in for dry runs)")

    catalog = catalog or si.load_catalog()
    if manifest["catalogSha256"] != si.file_sha256(si.CATALOG):
        problems.append("catalogSha256 differs from scripts/sptd/integration/demos.json in this checkout")
    steps = {s["id"]: s for s in catalog["steps"]}
    order = [s["id"] for s in catalog["steps"]]
    seen_steps = [step["id"] for demo in manifest["demos"] for step in demo["steps"]]
    unknown = [sid for sid in seen_steps if sid not in steps]
    if unknown:
        problems.append("steps not in the catalog: " + ", ".join(unknown))
    elif [order.index(sid) for sid in seen_steps] != sorted(order.index(sid) for sid in seen_steps):
        problems.append("steps are not in catalog order: " + ", ".join(seen_steps))
    if len(set(seen_steps)) != len(seen_steps):
        problems.append("a step appears twice")
    for demo in manifest["demos"]:
        for step in demo["steps"]:
            entry = steps.get(step["id"])
            if entry and (entry["demo"] != demo["demo"] or entry["phase"] != step["phase"]):
                problems.append(f"step {step['id']}: demo/phase differ from the catalog")
    if require_complete:
        missing = [s["id"] for s in catalog["steps"] if s["id"] not in seen_steps]
        if missing:
            problems.append("incomplete set, missing steps: " + ", ".join(missing))

    registry = manifest["registry"]
    history = registry["history"]
    if [h["step"] for h in history] != seen_steps:
        problems.append("registry history does not list every step in order")
    counts = [h["profileCount"] for h in history]
    if counts != sorted(counts) or counts[-1] != len(registry["profiles"]):
        problems.append("registry history is not append-only up to the final registry")
    if history[-1]["sha256"] != registry["sha256"]:
        problems.append("the final history entry is not the installed registry")
    profiles = [role["profile"] for demo in manifest["demos"] for step in demo["steps"] for role in step["roles"]]
    if len(set(profiles)) != len(profiles):
        problems.append("a profile is used by two roles")
    missing = sorted(set(profiles) - set(registry["profiles"]))
    if missing:
        problems.append("roles whose profile is not in the registry: " + ", ".join(missing))
    extra = sorted(set(registry["profiles"]) - set(profiles))
    if extra and registry["installMode"] == "fresh":
        problems.append("registry profiles without a role in a fresh set: " + ", ".join(extra))
    if registry["installMode"] == "fresh" and history[0]["profileCount"] < 1:
        problems.append("empty base registry")

    plans = {p["name"]: p for p in manifest["podPlans"]}
    if len(plans) != len(manifest["podPlans"]):
        problems.append("duplicate Pod plan names")
    if len({(p["namespace"], p["podName"]) for p in manifest["podPlans"]}) != len(manifest["podPlans"]):
        problems.append("two Pod plans for one namespace/pod")
    for plan in manifest["podPlans"]:
        if plan["namespace"] != manifest["namespace"]:
            problems.append(f"Pod plan {plan['name']} is for namespace {plan['namespace']}, the set for {manifest['namespace']}")
    used = set()
    for demo in manifest["demos"]:
        for step in demo["steps"]:
            for role in step["roles"]:
                if role["podPlan"] is not None:
                    used.add(role["podPlan"])
                    if role["podPlan"] not in plans:
                        problems.append(f"{step['id']}/{role['container']}: Pod plan {role['podPlan']} is not in the set")
                if not role["imageReference"].endswith("@" + role["imageManifestDigest"]):
                    problems.append(f"{step['id']}/{role['container']}: image reference and manifest digest differ")
    if set(plans) - used:
        problems.append("Pod plans no role uses: " + ", ".join(sorted(set(plans) - used)))
    if plans and manifest["facts"]["nodeContract"] != "V7":
        problems.append("Pod plans need a V7 node contract")

    if facts is not None:
        problems += _facts_problems(manifest, facts, facts_path)

    goroot = manifest["facts"]["goRootArtifactDigest"]
    for demo in manifest["demos"]:
        for step in demo["steps"]:
            if steps.get(step["id"], {}).get("goRoot") and not manifest["facts"]["standIn"]:
                for role in step["roles"]:
                    if role["bundle"]["artifactDigest"] != goroot:
                        problems.append(f"{step['id']}/{role['container']}: rootfs artifact is not the landed Go root")
            if manifest["facts"]["launcherRoute"] == "detached-generic":
                for role in step["roles"]:
                    if role["bundle"]["schema"] != "scone-dev-onboard-bundle-v2" or \
                            role["bundle"].get("launcherSha256") != manifest["facts"]["launcherSha256"]:
                        problems.append(f"{step['id']}/{role['container']}: bundle does not bind the generic launcher")

    if set_dir is not None:
        problems += _file_problems(manifest, set_dir, deep)
    if problems:
        raise si.Invalid("manifest is not valid:\n  " + "\n  ".join(problems))
    return {"artifactSetSha256": manifest["artifactSetSha256"], "steps": len(seen_steps),
            "roles": len(profiles), "podPlans": len(plans), "registryProfiles": len(registry["profiles"])}


def _facts_problems(manifest, facts, facts_path):
    problems = []
    if facts_path and si.file_sha256(facts_path) != manifest["facts"]["sha256"]:
        problems.append("facts file differs from the one the set was built from")
    expected = {
        "standIn": facts["standIn"], "nodeImageDigest": facts["nodeImage"]["digest"],
        "nodeContract": facts["nodeImage"]["contract"], "managerId": facts["managerId"],
        "goRootArtifactDigest": facts["goRoot"]["artifactDigest"], "envcasCommit": facts["envcas"]["commit"],
        "launcherRoute": facts["launcher"]["route"], "launcherSha256": facts["launcher"]["sha256"],
        "rootPin": facts["devRegistry"]["rootPin"],
    }
    for key, value in expected.items():
        if manifest["facts"][key] != value:
            problems.append(f"facts.{key} differs from the facts file")
    if manifest["sources"] != {"demosCommit": facts["demos"]["commit"], "onboardCommit": facts["onboard"]["commit"]}:
        problems.append("source commits differ from the facts file")
    wants_append = bool(facts["devRegistry"].get("installedOnImage"))
    if wants_append != (manifest["registry"]["installMode"] == "append"):
        problems.append("registry installMode does not match whether the node image ships a registry")
    # The shipped base registry itself is hash-checked by the devvm script before step 1.
    return problems


def _scan_private_key(path):
    if os.path.getsize(path) > SCAN_LIMIT:
        return False
    with open(path, "rb") as handle:
        data = handle.read()
    return any(marker in data for marker in PRIVATE_KEY_MARKERS)


def _file_problems(manifest, set_dir, deep):
    problems = []
    for rel, digest in manifest["files"].items():
        path = os.path.join(set_dir, rel)
        if not os.path.isfile(path):
            problems.append(f"missing file {rel}")
            continue
        if si.file_sha256(path) != digest:
            problems.append(f"digest mismatch {rel}")
        if _scan_private_key(path):
            problems.append(f"{rel} holds private-key material")
    registry = manifest["registry"]
    for suffix, field in (("", "sha256"), (".sig", "sigSha256"), (".root.pem", "rootPemSha256")):
        if manifest["files"].get(f"node-set/profile-registry.json{suffix}") != registry[field]:
            problems.append(f"registry.{field} is not the pinned node-set file")
    reg_path = os.path.join(set_dir, "node-set", "profile-registry.json")
    if os.path.isfile(reg_path):
        try:
            names = [entry["profile"] for entry in si.load_json(reg_path)["profiles"]]
        except (ValueError, KeyError, TypeError):
            names = None
        if names != registry["profiles"]:
            problems.append("node-set registry profiles differ from registry.profiles")
    for plan in manifest["podPlans"]:
        for suffix, field in (("", "sha256"), (".sig", "sigSha256"), (".root.pem", "rootPemSha256")):
            if manifest["files"].get(f"node-set/pod-plans/{plan['name']}.json{suffix}") != plan[field]:
                problems.append(f"Pod plan {plan['name']}{suffix} is not a pinned node-set file")
    node_set = os.path.join(set_dir, "node-set")
    if os.path.isdir(node_set):
        for root, _, names in os.walk(node_set):
            for name in names:
                rel = os.path.relpath(os.path.join(root, name), set_dir).replace(os.sep, "/")
                if rel not in manifest["files"]:
                    # provision-dev-registry refuses unknown files; keep the set exact.
                    problems.append(f"unpinned file in node-set: {rel}")
    for demo in manifest["demos"]:
        for step in demo["steps"]:
            for rel in [step["outputManifest"]] + step["nativeManifests"] + step.get("supportManifests", []):
                if rel not in manifest["files"]:
                    problems.append(f"{step['id']}: {rel} is not pinned in files")
            for role in step["roles"]:
                bundle = role["bundle"]
                for name, field in (("checksums.json", "checksumsSha256"), ("bundle.json", "bundleJsonSha256")):
                    if manifest["files"].get(f"{bundle['dir']}/{name}") != bundle[field]:
                        problems.append(f"{bundle['dir']}/{name} is not pinned in files")
                checks = os.path.join(set_dir, bundle["dir"], "checksums.json")
                if deep and os.path.isfile(checks):
                    for rel, digest in si.load_json(checks).items():
                        path = os.path.join(set_dir, bundle["dir"], rel)
                        if not os.path.isfile(path) or si.file_sha256(path) != digest:
                            problems.append(f"{bundle['dir']}/{rel}: bundle checksum mismatch")
                        elif _scan_private_key(path):
                            problems.append(f"{bundle['dir']}/{rel} holds private-key material")
    return problems


def add_validate_arguments(parser):
    parser.add_argument("manifest")
    parser.add_argument("--set", dest="set_dir", help="artifact-set directory (default: the manifest's directory)")
    parser.add_argument("--facts", help="landed-image facts file the set must match")
    parser.add_argument("--expect-hash", help="artifact-set hash the caller pinned (sha256:<hex>)")
    parser.add_argument("--require-complete", action="store_true", help="every catalog step must be present")
    parser.add_argument("--deep", action="store_true", help="also re-hash every bundle file")
    parser.add_argument("--allow-stand-in", action="store_true", help="accept a set built from stand-in facts")
    parser.add_argument("--no-files", action="store_true", help="check the manifest only, not the files")


def cmd_validate(args):
    manifest = si.load_json(args.manifest)
    facts = si.load_facts(args.facts) if args.facts else None
    set_dir = None if args.no_files else (args.set_dir or os.path.dirname(os.path.abspath(args.manifest)))
    summary = validate(manifest, set_dir=set_dir, facts=facts, facts_path=args.facts, expect_hash=args.expect_hash,
                       require_complete=args.require_complete, deep=args.deep, allow_stand_in=args.allow_stand_in)
    print(json.dumps(dict(summary, valid=True), sort_keys=True))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="artifact_manifest.py", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    add_validate_arguments(sub.add_parser("validate"))
    sub.add_parser("hash").add_argument("manifest")
    args = parser.parse_args(argv)
    try:
        if args.command == "hash":
            print(si.artifact_set_sha256(si.load_json(args.manifest)))
            return 0
        return cmd_validate(args)
    except (si.Invalid, OSError, ValueError, KeyError) as error:
        print(f"artifact_manifest.py {args.command}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
