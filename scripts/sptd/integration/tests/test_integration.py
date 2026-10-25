#!/usr/bin/env python3
"""Unit tests for scripts/sptd/integration (stdlib only; no cluster, no key, no network).

Run: python3 scripts/sptd/integration/tests/test_integration.py   (or `make test`)
"""
import copy
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

TESTS = os.path.dirname(os.path.abspath(__file__))
INTEG = os.path.dirname(TESTS)
sys.path.insert(0, INTEG)
sys.path.insert(0, TESTS)

import sptdinteg as si  # noqa: E402
import reonboard_all  # noqa: E402
import artifact_manifest  # noqa: E402
import provision_dev_node  # noqa: E402
import deploy_demo  # noqa: E402
import fakerun  # noqa: E402

REPO = si.REPO_ROOT
STANDIN = os.path.join(INTEG, "facts.standin-envcas-main-20261025.json")
WORKFLOW = os.path.join(REPO, ".github", "workflows", "sptd-integration.yml")
ENVCAS_MAIN = "f69a0a61914d8ff53fb168c9b800c8e65a2c5c5b"


def read(path):
    with open(path) as handle:
        return handle.read()


def write(path, text):
    with open(path, "w") as handle:
        handle.write(text)


def quiet(fn, *args, **kwargs):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        result = fn(*args, **kwargs)
    return result, out.getvalue(), err.getvalue()


def real_facts(tmp, **changes):
    """A non-stand-in facts file with nonzero TEST digests."""
    facts = si.load_json(STANDIN)
    facts.update(standIn=False, managerId="test-manager-1")
    facts["nodeImage"]["digest"] = "sha256:" + "1" * 64
    facts["goRoot"]["artifactDigest"] = "sha256:" + "2" * 64
    facts["launcher"]["sha256"] = "sha256:" + "3" * 64
    for key, value in changes.items():
        facts[key] = value
    path = os.path.join(tmp, "facts.json")
    with open(path, "w") as handle:
        json.dump(facts, handle)
    return path, facts


class CatalogAndSchema(unittest.TestCase):
    def test_catalog_order_and_coverage(self):
        catalog = si.load_catalog()
        demos = si.catalog_demos(catalog)
        self.assertEqual(len(demos), 11)
        self.assertEqual(demos[0], "go-args-env-file")
        self.assertEqual({s["phase"] for s in catalog["steps"][:5]}, {"base"})
        self.assertEqual([s["id"] for s in catalog["steps"] if s["status"] != "ready"], ["flask-redis"])
        for step in catalog["steps"]:
            self.assertTrue(step["deploy"]["wait"] and step["deploy"]["checks"], step["id"])
            self.assertTrue(os.path.isdir(os.path.join(REPO, step["dir"])), step["dir"])
            self.assertIn(step["scone"], " ".join(" ".join(r) for r in step["render"]), step["id"])
            for argv in step["render"]:
                template = argv[argv.index("--file") + 1]
                self.assertTrue(os.path.isfile(os.path.join(REPO, step["dir"], template)), (step["id"], template))

    def test_block4_base_set(self):
        base = [s["demo"] for s in si.load_catalog()["steps"] if s["phase"] == "base"]
        self.assertEqual(sorted(base), sorted(["go-args-env-file", "configmap", "java-args-env-file",
                                               "web-server", "pet-clinic"]))

    def test_schema_interpreter(self):
        schema = {"type": "object", "required": ["a"], "additionalProperties": False,
                  "properties": {"a": {"type": "string", "pattern": "^x+$"}, "b": {"$ref": "#/$defs/n"}},
                  "$defs": {"n": {"type": "integer", "minimum": 2}}}
        self.assertEqual(si.schema_errors({"a": "xx", "b": 3}, schema), [])
        self.assertTrue(si.schema_errors({"a": "y"}, schema))
        self.assertTrue(si.schema_errors({"a": "x", "b": 1}, schema))
        self.assertTrue(si.schema_errors({"a": "x", "c": 1}, schema))
        self.assertTrue(si.schema_errors({"a": "x", "b": True}, schema))
        self.assertIn("unsupported keywords", si.schema_errors(1, {"oneOf": []})[0])

    def test_pinned_schemas_use_supported_keywords_only(self):
        for path in (si.MANIFEST_SCHEMA, si.FACTS_SCHEMA):
            schema = si.load_json(path)

            def walk(node):
                if isinstance(node, dict):
                    keys = set(node) - si._KNOWN
                    # property names inside "properties" are data, not keywords
                    for key, value in node.items():
                        if key in ("properties", "$defs"):
                            for item in value.values():
                                walk(item)
                        elif key not in ("enum", "const", "required", "examples"):
                            walk(value)
                    return keys
                if isinstance(node, list):
                    for item in node:
                        walk(item)

            self.assertEqual(walk(schema), set(), path)

    def test_facts(self):
        facts = si.load_facts(STANDIN)
        self.assertTrue(facts["standIn"])
        self.assertEqual(facts["envcas"]["commit"], ENVCAS_MAIN)
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = real_facts(tmp, managerId="STAND-IN-x")
            with self.assertRaisesRegex(si.Invalid, "real manager id"):
                si.load_facts(path)
            path, facts = real_facts(tmp)
            facts["goRoot"]["artifactDigest"] = si.ZERO_DIGEST
            write(path, json.dumps(facts))
            with self.assertRaisesRegex(si.Invalid, "zero digests"):
                si.load_facts(path)
            facts["goRoot"]["artifactDigest"] = "sha256:" + "2" * 64
            facts["devRegistry"]["rootPin"] = "sha256:" + "a" * 64
            write(path, json.dumps(facts))
            with self.assertRaisesRegex(si.Invalid, "rootPin"):
                si.load_facts(path)

    def test_plan_file_name(self):
        self.assertEqual(si.plan_file_name("default", "my-rust-app"), "default.my-rust-app")
        with self.assertRaises(si.Invalid):
            si.plan_file_name("default", "My_App")


class Plan(unittest.TestCase):
    def plan(self, *extra, facts=STANDIN):
        return quiet(reonboard_all.main, ["plan", "--facts", facts, *extra])

    def test_stand_in_needs_flag(self):
        rc, _, err = self.plan("--dry-run")
        self.assertEqual(rc, 1)
        self.assertIn("stand-in", err)

    def test_dry_run_against_envcas_main(self):
        rc, script, err = self.plan("--dry-run", "--allow-stand-in", "--namespace", "sptd-dev", "--node-name", "node-1")
        self.assertEqual(rc, 0, err)
        self.assertIn("nothing written", err)
        self.assertIn(f"ENVCAS_COMMIT={ENVCAS_MAIN}", script)
        self.assertIn("exit 3", script)  # a stand-in plan refuses to run
        self.assertIn("# not in this plan (pending): flask-redis", script)
        order = [line.split(":")[1].split("(")[0].strip() for line in script.splitlines()
                 if line.startswith("# ---- step ")]
        self.assertEqual(order, [s["id"] for s in si.load_catalog()["steps"] if s["status"] == "ready"])
        self.assertNotIn("BEGIN", script)
        self.assertIn(': "${SPTD_DEV_SIGNING_KEY:?', script)
        self.assertEqual(script.count("scone-td-build apply -f"), 11)
        self.assertIn("SPTD_A8_COMPILER_FEATURES=nonrelease-dev-baked-volumes", script)
        with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as handle:
            handle.write(script)
        try:
            subprocess.run(["bash", "-n", handle.name], check=True)
            if shutil.which("shellcheck"):
                subprocess.run(["shellcheck", "-S", "warning", handle.name], check=True)
        finally:
            os.unlink(handle.name)

    def test_real_facts_plan_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = real_facts(tmp)
            out = os.path.join(tmp, "plan")
            rc, text, err = self.plan("--out", out, "--include-pending", "--node-name", "node-1", facts=path)
            self.assertEqual(rc, 0, err)
            script = read(os.path.join(out, "reonboard-devvm.sh"))
            self.assertNotIn("exit 3", script)
            self.assertTrue(os.stat(os.path.join(out, "reonboard-devvm.sh")).st_mode & stat.S_IXUSR)
            for name in reonboard_all.INTEGRATION_FILES:
                self.assertTrue(os.path.isfile(os.path.join(out, "integration", name)), name)
            plan = si.load_json(os.path.join(out, "reonboard-plan.json"))
            self.assertEqual(len(plan["steps"]), 12)
            self.assertEqual(plan["steps"][1]["registryFrom"], "go-args-env-file")
            self.assertTrue(plan["signsNothing"])
            self.assertIn("flask-redis", text)

    def test_subset_keeps_catalog_order(self):
        rc, script, err = self.plan("--dry-run", "--allow-stand-in", "--demos", "hello-world,configmap")
        self.assertEqual(rc, 0, err)
        steps = [line for line in script.splitlines() if line.startswith("# ---- step ")]
        self.assertIn("configmap", steps[0])
        self.assertIn("hello-world", steps[1])
        rc, _, err = self.plan("--dry-run", "--allow-stand-in", "--demos", "nope")
        self.assertEqual(rc, 1)
        self.assertIn("unknown demo", err)

    def test_set_values_matches_prepare_example_ci(self):
        text = "environment:\n  NAMESPACE: default\n  TEE_TYPE: sgx\nother: 1\n"
        new = reonboard_all.upsert_values(reonboard_all.upsert_values(text, "TEE_TYPE", "sptd"), "EXTRA", "x")
        script = os.path.join(REPO, "scripts", "prepare-example-ci.sh")
        source = read(script)
        body = source[source.index("upsert_scalar() {"):source.index("ensure_namespace() {")]
        with tempfile.TemporaryDirectory() as tmp:
            values = os.path.join(tmp, "Values.yaml")
            write(values, text)
            subprocess.run(["bash", "-c", body + f'upsert_scalar "{values}" TEE_TYPE sptd; upsert_scalar "{values}" EXTRA x'],
                           check=True)
            self.assertEqual(read(values), new)
            rc, _, err = quiet(reonboard_all.main, ["set-values", values, "NAMESPACE=sptd-dev"])
            self.assertEqual(rc, 0, err)
            self.assertIn("  NAMESPACE: sptd-dev\n", read(values))


class CollectValidate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.facts_path, self.facts = real_facts(self.tmp)
        catalog = si.load_catalog()
        self.plan = reonboard_all.build_plan(self.facts, self.facts_path, catalog, include_pending=True,
                                             node_name="node-1", namespace="sptd-dev")
        self.work = os.path.join(self.tmp, "work")
        self.set = os.path.join(self.tmp, "set")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def collect(self, **fake):
        fakerun.fake_run(self.plan, self.work, go_root=self.facts["goRoot"]["artifactDigest"], **fake)
        return reonboard_all.collect(self.plan, self.work, self.set)

    def validate(self, manifest=None, **kwargs):
        manifest = manifest or si.load_json(os.path.join(self.set, "manifest.json"))
        return artifact_manifest.validate(manifest, set_dir=self.set, **kwargs)

    def test_round_trip(self):
        manifest = self.collect()
        summary = self.validate(facts=self.facts, facts_path=self.facts_path, deep=True, require_complete=True,
                                expect_hash=manifest["artifactSetSha256"])
        self.assertEqual(summary["steps"], 12)
        self.assertEqual(summary["podPlans"], 1)
        self.assertEqual(manifest["podPlans"][0]["name"], "sptd-dev.my-rust-app")
        self.assertEqual(sorted(os.listdir(os.path.join(self.set, "node-set"))),
                         ["pod-plans", "profile-registry.json", "profile-registry.json.root.pem",
                          "profile-registry.json.sig"])
        self.assertEqual(manifest["registry"]["installMode"], "fresh")
        self.assertEqual([h["profileCount"] for h in manifest["registry"]["history"]][:2], [1, 3])
        rc, out, _ = quiet(artifact_manifest.main, ["hash", os.path.join(self.set, "manifest.json")])
        self.assertEqual(out.strip(), manifest["artifactSetSha256"])
        rc, out, err = quiet(artifact_manifest.main, ["validate", os.path.join(self.set, "manifest.json"), "--deep",
                                                      "--facts", self.facts_path, "--require-complete"])
        self.assertEqual(rc, 0, err)

    def test_tampering_is_found(self):
        manifest = self.collect()
        with open(os.path.join(self.set, "steps", "hello-world", "output-manifest.yaml"), "a") as handle:
            handle.write("# changed\n")
        with self.assertRaisesRegex(si.Invalid, "digest mismatch steps/hello-world/output-manifest.yaml"):
            self.validate()
        changed = copy.deepcopy(manifest)
        changed["namespace"] = "other"
        with self.assertRaisesRegex(si.Invalid, "recomputed"):
            artifact_manifest.validate(changed)
        with self.assertRaisesRegex(si.Invalid, "expected sha256:"):
            artifact_manifest.validate(manifest, expect_hash="sha256:" + "9" * 64)

    def test_deep_finds_bundle_change(self):
        manifest = self.collect()
        role = manifest["demos"][0]["steps"][0]["roles"][0]
        with open(os.path.join(self.set, role["bundle"]["dir"], "rootfs.erofs"), "ab") as handle:
            handle.write(b"x")
        self.validate()
        with self.assertRaisesRegex(si.Invalid, "bundle checksum mismatch"):
            self.validate(deep=True)

    def test_private_key_is_refused(self):
        self.collect()
        manifest = si.load_json(os.path.join(self.set, "manifest.json"))
        rel = "steps/hello-world/native/manifest.job.yaml"
        with open(os.path.join(self.set, rel), "w") as handle:
            handle.write("-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n")
        manifest["files"][rel] = si.file_sha256(os.path.join(self.set, rel))
        manifest["artifactSetSha256"] = si.artifact_set_sha256(manifest)
        with self.assertRaisesRegex(si.Invalid, "private-key material"):
            self.validate(manifest)

    def test_unpinned_node_set_file(self):
        self.collect()
        write(os.path.join(self.set, "node-set", "extra.json"), "{}")
        with self.assertRaisesRegex(si.Invalid, "unpinned file in node-set"):
            self.validate()

    def test_registry_must_be_append_only(self):
        with self.assertRaisesRegex(si.Invalid, "does not extend"):
            self.collect(break_chain_at="hello-world")

    def test_refused_role_stops_collect(self):
        with self.assertRaisesRegex(si.Invalid, "refused role"):
            self.collect(refuse=("web-server", "web-server"))

    def test_facts_cross_check(self):
        manifest = self.collect()
        other_path, other = real_facts(os.path.join(self.tmp), managerId="test-manager-2")
        with self.assertRaisesRegex(si.Invalid, "managerId"):
            artifact_manifest.validate(manifest, facts=other, facts_path=other_path)

    def test_complete_and_stand_in(self):
        self.plan["steps"] = [s for s in self.plan["steps"] if s["id"] != "flask-redis"]
        manifest = self.collect()
        self.validate()
        with self.assertRaisesRegex(si.Invalid, "missing steps: flask-redis"):
            self.validate(require_complete=True)
        manifest["facts"]["standIn"] = True
        manifest["artifactSetSha256"] = si.artifact_set_sha256(manifest)
        with self.assertRaisesRegex(si.Invalid, "stand-in"):
            artifact_manifest.validate(manifest)
        artifact_manifest.validate(manifest, allow_stand_in=True)

    def test_go_root_and_detached_launcher(self):
        self.facts["launcher"]["route"] = "detached-generic"
        manifest = self.collect(launcher_v2=self.facts["launcher"]["sha256"])
        self.validate()
        role = manifest["demos"][0]["steps"][0]["roles"][0]
        self.assertEqual(role["bundle"]["launcherSha256"], self.facts["launcher"]["sha256"])
        bad = copy.deepcopy(manifest)
        bad["facts"]["goRootArtifactDigest"] = "sha256:" + "4" * 64
        bad["artifactSetSha256"] = si.artifact_set_sha256(bad)
        with self.assertRaisesRegex(si.Invalid, "landed Go root"):
            artifact_manifest.validate(bad)


class StandInSet(unittest.TestCase):
    """A stand-in set for the dry runs of the node and deploy scripts."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        facts = si.load_facts(STANDIN)
        plan = reonboard_all.build_plan(facts, STANDIN, si.load_catalog(), node_name="node-1",
                                        namespace="sptd-dev", allow_stand_in=True)
        work = os.path.join(cls.tmp, "work")
        fakerun.fake_run(plan, work)
        cls.set = os.path.join(cls.tmp, "set")
        cls.manifest = reonboard_all.collect(plan, work, cls.set)
        cls.hash = cls.manifest["artifactSetSha256"]

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp)


class Provision(StandInSet):
    def run_dry(self, *extra, state="fresh"):
        return quiet(provision_dev_node.main, ["--set", self.set, "--expect-hash", self.hash, "--node", "node-1",
                                               "--allow-stand-in", "--dry-run", "--assume-state", state, *extra])

    def test_fresh(self):
        rc, out, err = self.run_dry("--host-exec", "ssh root@node-1")
        self.assertEqual(rc, 0, err)
        lines = out.splitlines()
        self.assertTrue(all(line.startswith("[dry-run] ") for line in lines
                            if line.split(":")[0].endswith(("host", "kubectl", "host query", "kubectl query"))))
        self.assertIn("apply --server-side", out)
        self.assertIn("provision-dev-registry --from /root/sptd-node-set-", out)
        self.assertNotIn("--append", out)
        self.assertEqual(out.count("provision-dev-registry"), 2)
        self.assertIn("--confirm", out)
        self.assertIn("systemctl restart containerd.service", out)
        self.assertIn("--root-pin " + self.manifest["facts"]["rootPin"], out)

    def test_same_is_a_no_op(self):
        rc, out, err = self.run_dry(state="same")
        self.assertEqual(rc, 0, err)
        self.assertNotIn("provision-dev-registry", out)
        self.assertNotIn("restart containerd", out)
        self.assertNotIn("apply --server-side", out)
        self.assertIn("unchanged", out)

    def test_earlier_appends(self):
        rc, out, err = self.run_dry(state="earlier")
        self.assertEqual(rc, 0, err)
        self.assertIn("--append", out)
        self.assertIn("--append --confirm", out)

    def test_foreign_needs_clear(self):
        rc, _, err = self.run_dry(state="foreign")
        self.assertEqual(rc, 1)
        self.assertIn("--clear", err)
        rc, out, err = self.run_dry("--clear", state="foreign")
        self.assertEqual(rc, 0, err)
        self.assertIn("mv /etc/scone/scone-dev /root/scone-dev.moved-", out)
        self.assertNotIn("rm ", out)

    def test_refusals(self):
        rc, _, err = quiet(provision_dev_node.main, ["--set", self.set, "--expect-hash", "sha256:" + "0" * 64,
                                                     "--node", "node-1", "--allow-stand-in", "--dry-run"])
        self.assertEqual(rc, 1)
        rc, _, err = quiet(provision_dev_node.main, ["--set", self.set, "--expect-hash", self.hash,
                                                     "--node", "node-2", "--allow-stand-in", "--dry-run"])
        self.assertEqual(rc, 1)
        self.assertIn("onboarded for node node-1", err)
        rc, _, err = quiet(provision_dev_node.main, ["--set", self.set, "--expect-hash", self.hash,
                                                     "--node", "node-1", "--dry-run"])
        self.assertEqual(rc, 1)
        self.assertIn("stand-in", err)


KUBECTL_STUB = r"""#!/usr/bin/env bash
# TEST kubectl: logs every call; answers get/logs from $STUB_DIR files.
printf '%s\n' "$*" >> "$STUB_DIR/calls"
case " $* " in
  *" logs "*) cat "$STUB_DIR/logs" 2>/dev/null ;;
  *"status.phase"*) echo Succeeded ;;
  *"metadata.name"*) echo pod-1 ;;
  *" port-forward "*) exit 1 ;;
esac
exit 0
"""


class Deploy(StandInSet):
    def args(self, *extra):
        return ["--set", self.set, "--expect-hash", self.hash, "--node", "node-1", "--allow-stand-in",
                "--image-digest", self.manifest["facts"]["nodeImageDigest"], *extra]

    def test_dry_run_order(self):
        rc, out, err = quiet(deploy_demo.main, self.args("--dry-run", "--demos", "hello-world"))
        self.assertEqual(rc, 0, err)
        self.assertIn("native=DRY-RUN ready=DRY-RUN check=DRY-RUN", out)
        self.assertNotIn("PASS", out)
        calls = [line for line in out.splitlines() if line.startswith("[dry-run] kubectl:")]
        self.assertIn("apply -f", calls[0])
        self.assertIn("native/manifest.job.yaml", calls[0])
        confidential = [i for i, c in enumerate(calls) if "output-manifest.yaml" in c]
        self.assertIn("apply", calls[confidential[0]])
        self.assertIn("delete", calls[confidential[-1]])
        self.assertTrue(all("-n sptd-dev" in c for c in calls))

    def test_refusals(self):
        rc, _, err = quiet(deploy_demo.main, self.args("--dry-run", "--demos", "nope"))
        self.assertEqual(rc, 1)
        args = self.args("--dry-run")
        args[args.index("--image-digest") + 1] = "sha256:" + "5" * 64
        rc, _, err = quiet(deploy_demo.main, args)
        self.assertEqual(rc, 1)
        self.assertIn("node image", err)
        rc, _, err = quiet(deploy_demo.main, self.args("--dry-run", "--namespace", "other", "--demos", "configmap"))
        self.assertEqual(rc, 1)
        self.assertIn("bind namespace", err)

    def test_stub_kubectl(self):
        with tempfile.TemporaryDirectory() as stub:
            kubectl = os.path.join(stub, "kubectl")
            write(kubectl, KUBECTL_STUB)
            os.chmod(kubectl, 0o755)
            os.environ["STUB_DIR"] = stub
            report = os.path.join(stub, "report.json")
            try:
                write(os.path.join(stub, "logs"), "hello from the demo\n")
                rc, out, err = quiet(deploy_demo.main, self.args("--kubectl", kubectl, "--demos", "hello-world,configmap",
                                                                 "--report", report))
                self.assertEqual(rc, 0, out + err)
                result = si.load_json(report)
                self.assertTrue(result["passed"])
                self.assertEqual([r["step"] for r in result["results"]], ["configmap", "hello-world"])
                # A failing check still cleans up.
                open(os.path.join(stub, "calls"), "w").close()
                write(os.path.join(stub, "logs"), "")
                rc, out, _ = quiet(deploy_demo.main, self.args("--kubectl", kubectl, "--demos", "hello-world",
                                                               "--skip-native", "--report", report))
                self.assertEqual(rc, 2)
                result = si.load_json(report)["results"][0]
                self.assertTrue(result["check"].startswith("FAIL"))
                self.assertEqual(result["cleanup"], "DONE")
                self.assertIn("delete --ignore-not-found", read(os.path.join(stub, "calls")))
            finally:
                del os.environ["STUB_DIR"]


class Workflow(unittest.TestCase):
    """The installed .github/workflows/sptd-integration.yml: dispatch only, unused label, read-only."""

    def setUp(self):
        with open(WORKFLOW) as handle:
            self.text = handle.read()
        self.head = self.text.split("\njobs:", 1)[0]

    def test_trigger_and_inputs(self):
        self.assertIn("\non:\n  workflow_dispatch:\n", self.head)
        for trigger in ("pull_request", "push:", "schedule", "workflow_run", "pull_request_target",
                        "repository_dispatch", "workflow_call"):
            self.assertNotIn(trigger, self.text)
        for name in ("artifact_set_sha256", "node", "image_digest", "demos"):
            self.assertIn(f"      {name}:", self.head)

    def test_runner_label_permissions_concurrency(self):
        runs_on = [line.strip() for line in self.text.splitlines() if line.strip().startswith("runs-on:")]
        self.assertTrue(runs_on)
        self.assertEqual(set(runs_on), {"runs-on: [self-hosted, sptd-integration]"})
        self.assertNotIn("scone-sgx", self.text)
        self.assertIn("\npermissions:\n  contents: read\n", self.head)
        self.assertNotIn("write", self.text.split("permissions:", 1)[1].split("\n\n", 1)[0])
        self.assertIn("\nconcurrency:\n  group: ", self.head)

    def test_actions_pinned_and_no_keys(self):
        uses = [line.split("uses:", 1)[1].split("#")[0].strip() for line in self.text.splitlines()
                if "uses:" in line]
        self.assertTrue(uses)
        for ref in uses:
            self.assertRegex(ref, r"^[a-z-]+/[a-z-]+@[0-9a-f]{40}$")
        for secret in [s.split("}}")[0].strip() for s in self.text.split("secrets.")[1:]]:
            self.assertTrue(secret.startswith("PLACEHOLDER_"), secret)
        self.assertNotIn("SIGNING_KEY", self.text)
        self.assertNotIn("reonboard_all.py", self.text)
        self.assertNotIn("docker", self.text)
        self.assertIn("deploy_demo.py", self.text)

    def test_yaml_shape(self):
        try:
            import yaml
        except ImportError:
            self.skipTest("PyYAML not installed")
        workflow = yaml.safe_load(self.text)
        triggers = workflow.get("on", workflow.get(True))
        self.assertEqual(list(triggers), ["workflow_dispatch"])
        self.assertEqual(workflow["permissions"], {"contents": "read"})
        for job in workflow["jobs"].values():
            self.assertEqual(job["runs-on"], ["self-hosted", "sptd-integration"])
            self.assertIn("timeout-minutes", job)


if __name__ == "__main__":
    unittest.main(verbosity=1)
