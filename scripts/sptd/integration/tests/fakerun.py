"""Fake devvm re-onboarding run for the tests: the directory layout td-build-sptd.py and
onboard.py leave behind (summary, bundles, registry chain, Pod plans), with TEST bytes only.
No key exists here; the ".sig" files are random bytes and ".root.pem" a dummy public key."""
import hashlib
import json
import os

PUBLIC_PEM = b"-----BEGIN PUBLIC KEY-----\nTEST-ONLY-NOT-A-KEY\n-----END PUBLIC KEY-----\n"

# Roles per step: (workload, container, needs a Pod plan)
ROLES = {
    "configmap": [("Job/my-rust-app", "reader-1", True), ("Job/my-rust-app", "reader-2", True)],
    "network-policy": [("Deployment/client", "client", False), ("Deployment/server", "server", False)],
    "flask-redis-netshield": [("Deployment/redis", "redis", False), ("Deployment/flask-api", "flask-api", False)],
    "flask-redis": [("Deployment/redis", "redis", False), ("Deployment/flask-api", "flask-api", False)],
}


def digest(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data if isinstance(data, bytes) else data.encode())


def dump(path, value):
    write(path, json.dumps(value, indent=2, sort_keys=True) + "\n")


def fake_run(plan, work, go_root=None, launcher_v2=None, refuse=None, break_chain_at=None):
    """Create WORK/steps/<id>/... as the devvm script would. Returns the final registry path."""
    pin = plan["rootPin"]
    namespace = plan["namespace"]
    profiles = []
    registry_path = None
    for step in plan["steps"]:
        sid, demo = step["id"], step["demo"]
        step_dir = os.path.join(work, "steps", sid)
        swork = os.path.join(step_dir, "work")
        results = []
        plan_json = None
        roles = ROLES.get(demo, [(f"Job/{sid}", demo, False)])
        if break_chain_at == sid:
            profiles = profiles[1:]
        for workload, container, needs_plan in roles:
            name = workload.split("/", 1)[1]
            profile = f"{sid}-{container}"[:63].strip("-")
            cwork = os.path.join(swork, "a8", demo, name, container)
            bundle = os.path.join(cwork, "bundle")
            dump(os.path.join(cwork, "request.json"), {"schema": "scone-dev-onboard-request-v1", "profile_id": profile})
            files = {
                "rootfs.erofs": f"rootfs {sid} {container}".encode(),
                "envcas-rs": f"sealed launcher {sid} {container}".encode(),
                "profile/profile.cbor": f"profile {profile}".encode(),
                "profile/profile.sig": os.urandom(64),
                "profile/root.spki.der": b"TEST public spki",
                "contract.json": json.dumps({"image": {"reference": f"registry.invalid/{sid}@{digest(sid.encode())}"}}).encode(),
            }
            for rel, data in files.items():
                write(os.path.join(bundle, rel), data)
            entry = {"profile": profile, "repository": f"registry.invalid/{sid}", "tag": f"sptd-dev-{profile}",
                     "config_id": f"scone/{profile}", "config_digest": digest(f"config {profile}".encode()),
                     "contract_digest": digest(f"contract {profile}".encode()),
                     "profile_digest": digest(f"profile {profile}".encode())}
            profiles = profiles + [entry]
            registry = {"schema": "sptd-dev-profile-registry-v1", "runtime_handler": "scone-dev", "profiles": profiles}
            write(os.path.join(bundle, "profile-registry.json"), json.dumps(registry, sort_keys=True))
            write(os.path.join(bundle, "profile-registry.json.sig"), os.urandom(64))
            write(os.path.join(bundle, "profile-registry.json.root.pem"), PUBLIC_PEM)
            report = {"schema": "scone-dev-onboard-bundle-v1", "status": "signed-offline-dev-bundle",
                      "runtimeReady": False, "rootPin": pin, "profileDigest": entry["profile_digest"],
                      "contractDigest": entry["contract_digest"], "imageConfigDigest": entry["config_digest"],
                      "artifactDigest": go_root if (go_root and step.get("id") == "go-args-env-file")
                      else digest(f"artifact {profile}".encode()),
                      "toolDigests": {"compiler": digest(b"compiler")}}
            if launcher_v2:
                report.update(schema="scone-dev-onboard-bundle-v2", bootstrapToolDigests={"launcher_sha256": launcher_v2[7:]})
            dump(os.path.join(bundle, "bundle.json"), report)
            checksums = {}
            for root, _, names in os.walk(bundle):
                for item in names:
                    path = os.path.join(root, item)
                    with open(path, "rb") as handle:
                        checksums[os.path.relpath(path, bundle)] = digest(handle.read())
            dump(os.path.join(bundle, "checksums.json"), checksums)
            registry_path = os.path.join(bundle, "profile-registry.json")
            result = {"demo": demo, "workload": workload, "container": container,
                      "source": f"registry.invalid/{sid}:native", "result": "PASS", "bundle": bundle,
                      "image": f"registry.invalid/{sid}@{digest((sid + container).encode())}",
                      "registry": registry_path, "podPlan": None}
            if refuse == (sid, container):
                result = {"demo": demo, "workload": workload, "container": container, "result": "REFUSED",
                          "refusal": "test refusal"}
            if needs_plan:
                plan_dir = os.path.join(swork, "a8", demo, name, ".pod-plan", "plan")
                plan_json = os.path.join(plan_dir, "pod-plan.json")
                result["podPlan"] = plan_json
            results.append(result)
        if plan_json:
            body = json.dumps({"namespace": namespace, "pod_name": "my-rust-app", "roles": [r["container"] for r in results]})
            collected = os.path.join(swork, "a8", "pod-plans", f"{namespace}_my-rust-app.pod-plan.json")
            sig = os.urandom(64)
            for target in (plan_json, collected):
                write(target, body)
                write(target + ".sig", sig)
                write(target + ".root.pem", PUBLIC_PEM)
        dump(os.path.join(swork, "a8", f"{demo}.summary.json"),
             {"demo": demo, "results": results, "registry": registry_path})
        dump(os.path.join(step_dir, "summary.json"), {"demo": demo, "results": results, "registry": registry_path})
        write(os.path.join(step_dir, "output-manifest.yaml"), f"# confidential {sid}\nkind: Job\n")
        for native in dict.fromkeys(step["nativeManifests"] + step["supportManifests"]):
            write(os.path.join(step_dir, "native", native), f"# native {sid} {native}\nkind: Job\n")
    return registry_path
