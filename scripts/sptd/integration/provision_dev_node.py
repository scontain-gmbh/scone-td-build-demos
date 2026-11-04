#!/usr/bin/env python3
"""Provision the sptd dev node for one artifact set, idempotently (docs/sptd-integration.md). NON_RELEASE.

  provision_dev_node.py --set DIR --expect-hash sha256:... --node NAME
                        [--host-exec "ssh root@node"] [--kubectl kubectl]
                        [--archive components.tar --archive-sha256 sha256:...]
                        [--helper-sha256 sha256:...] [--clear] [--dry-run [--assume-state S]]

What it does, in order (every step checks first and acts only when needed):

  1. validate the artifact set (artifact_manifest.py) and its pinned hash; the node name
     must be the one the set was onboarded for
  2. node component archive: optional local archive digest check; on the host the
     installed sptd-k8s-node helper (optional digest pin) and sptd-k8s-node.service active
  3. RuntimeClass scone-dev with handler scone-dev (applied only when missing; a different
     handler is refused)
  4. the signed set (registry + Pod plans) under /etc/scone/scone-dev with
     `sptd-k8s-node provision-dev-registry`: fresh install, --append when the installed
     registry is an earlier state of this set, nothing when it is already this set; any
     other installed set is refused unless --clear moves /etc/scone/scone-dev aside first
     (never deleted). Always verify-only first, then --confirm.
  5. restart containerd only when the set changed, then read the installed registry back

Host actions run as `<host-exec> sh -c '...'` (default: locally, as root on the node).
--dry-run executes nothing and prints every kubectl and host action, answering the host
and cluster queries from --assume-state.
"""
import argparse
import os
import shlex
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sptdinteg as si  # noqa: E402
import artifact_manifest  # noqa: E402

HELPER = "/usr/libexec/extra-components/sptd-k8s/sptd-k8s-node"
TARGET = "/etc/scone/scone-dev"
RUNTIME_CLASS = """apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: scone-dev
handler: scone-dev
"""
STATES = ("fresh", "same", "earlier", "foreign")


class Refused(Exception):
    pass


class Runner:
    """Runs (or, in a dry run, prints) host and kubectl commands."""

    def __init__(self, host_exec, kubectl, dry_run, assume, out=None):
        self.host_exec = shlex.split(host_exec) if host_exec else []
        self.kubectl = shlex.split(kubectl)
        self.dry_run = dry_run
        self.assume = assume or {}
        self.out = out or sys.stdout
        self.actions = []

    def _show(self, kind, text):
        line = f"{'[dry-run] ' if self.dry_run else ''}{kind}: {text}"
        self.actions.append((kind, text))
        print(line, file=self.out, flush=True)

    def host(self, script, query=None, stdin=None):
        """query: name of the dry-run answer to return instead of running."""
        argv = self.host_exec + ["sh", "-c", script]
        self._show("host query" if query else "host", script)
        if self.dry_run:
            return self.assume.get(query, "") if query else ""
        result = subprocess.run(argv, input=stdin, capture_output=True)
        if result.returncode and not query:
            raise Refused(f"host action failed (rc={result.returncode}): "
                          + result.stderr.decode(errors="replace").strip()[-400:])
        return result.stdout.decode(errors="replace").strip() if result.returncode == 0 else ""

    def host_copy(self, set_dir, rel, staging):
        """tar the node-set to the host staging directory (idempotent: same names, same bytes)."""
        script = f"install -d -m 0700 {shlex.quote(staging)} && tar -C {shlex.quote(staging)} -xf -"
        self._show("host", f"tar -C {set_dir} -cf - {rel} | {script}")
        if self.dry_run:
            return
        tar = subprocess.run(["tar", "-C", set_dir, "-cf", "-", rel], capture_output=True, check=True)
        result = subprocess.run(self.host_exec + ["sh", "-c", script], input=tar.stdout, capture_output=True)
        if result.returncode:
            raise Refused("copying the node set failed: " + result.stderr.decode(errors="replace").strip()[-400:])

    def kube(self, args, query=None, stdin=None):
        self._show("kubectl query" if query else "kubectl",
                   " ".join(shlex.quote(a) for a in self.kubectl + args) + (" <<EOF (RuntimeClass)" if stdin else ""))
        if self.dry_run:
            return self.assume.get(query, "") if query else ""
        result = subprocess.run(self.kubectl + args, input=stdin.encode() if stdin else None, capture_output=True)
        if result.returncode and not query:
            raise Refused(f"kubectl {' '.join(args)} failed: " + result.stderr.decode(errors="replace").strip()[-400:])
        return result.stdout.decode(errors="replace").strip() if result.returncode == 0 else ""


def assumed(state, manifest):
    """Dry-run answers for the queries, for one assumed node state."""
    registry = manifest["registry"]
    earlier = registry["history"][0]["sha256"] if len(registry["history"]) > 1 else si.ZERO_DIGEST
    installed = {"fresh": "absent", "same": registry["sha256"], "earlier": earlier,
                 "foreign": "sha256:" + "f" * 64}[state]
    plans = "" if state in ("fresh", "foreign") else "\n".join(
        f"{p['sha256'][7:]}  {TARGET}/pod-plans/{p['name']}.json" for p in manifest["podPlans"]
        if state == "same" or p["step"] == registry["history"][0]["step"])
    return {"etc-scone": "present", "helper": "sha256:" + "a" * 64, "unit": "active", "node": "True",
            "runtimeclass": "scone-dev" if state != "fresh" else "", "registry": installed, "plans": plans,
            "after": registry["sha256"]}


def node_state(runner, manifest):
    raw = runner.host(f"if [ -f {TARGET}/profile-registry.json ]; then printf 'sha256:'; "
                      f"sha256sum {TARGET}/profile-registry.json | cut -d' ' -f1; else echo absent; fi",
                      query="registry")
    installed = raw.strip() or "absent"
    plans_raw = runner.host(f"if [ -d {TARGET}/pod-plans ]; then cd {TARGET}/pod-plans && "
                            "for f in *.json; do [ -f \"$f\" ] && sha256sum \"$f\"; done; fi; true", query="plans")
    installed_plans = {}
    for line in plans_raw.splitlines():
        if line.strip():
            digest, name = line.split(None, 1)
            installed_plans[os.path.basename(name.strip())[: -len(".json")]] = "sha256:" + digest
    registry = manifest["registry"]
    wanted = {p["name"]: p["sha256"] for p in manifest["podPlans"]}
    if installed == "absent":
        return "fresh", installed, installed_plans
    if installed == registry["sha256"] and installed_plans == wanted:
        return "same", installed, installed_plans
    earlier = [h["sha256"] for h in registry["history"][:-1]]
    if installed in earlier and all(wanted.get(name) == digest for name, digest in installed_plans.items()):
        return "earlier", installed, installed_plans
    return "foreign", installed, installed_plans


def provision(args, runner, out=None):
    out = out or sys.stdout
    manifest_path = os.path.join(args.set, "manifest.json")
    manifest = si.load_json(manifest_path)
    summary = artifact_manifest.validate(manifest, set_dir=args.set, expect_hash=args.expect_hash,
                                         allow_stand_in=args.allow_stand_in)
    print(f"artifact set {summary['artifactSetSha256']}: {summary['steps']} steps, "
          f"{summary['registryProfiles']} profiles, {summary['podPlans']} Pod plans", file=out)
    if manifest["nodeName"] not in (None, args.node):
        raise Refused(f"the set was onboarded for node {manifest['nodeName']}, not {args.node}")
    pin = manifest["facts"]["rootPin"]

    # 2. node component archive and helper
    if args.archive:
        digest = si.file_sha256(args.archive)
        if digest != args.archive_sha256:
            raise Refused(f"archive {args.archive} is {digest}, expected {args.archive_sha256}")
        print(f"archive {args.archive}: {digest} (installed by the image build, #210; not by this script)", file=out)
    if runner.host("test -d /etc/scone && echo present", query="etc-scone") != "present":
        raise Refused("/etc/scone is missing on the node (not a dev-rbn-9-k8s image?)")
    helper = runner.host(f"printf 'sha256:'; sha256sum {HELPER} | cut -d' ' -f1", query="helper")
    if not si.SHA256.match(helper or ""):
        raise Refused(f"{HELPER} is not installed (node component archive missing)")
    if args.helper_sha256 and helper != args.helper_sha256:
        raise Refused(f"installed helper is {helper}, expected {args.helper_sha256}")
    if runner.host("systemctl is-active sptd-k8s-node.service", query="unit") != "active":
        runner.host("systemctl enable --now sptd-k8s-node.service")
    ready = runner.kube(["get", "node", args.node, "-o",
                         "jsonpath={.status.conditions[?(@.type==\"Ready\")].status}"], query="node")
    if ready != "True":
        print(f"note: node {args.node} is not Ready ({ready or 'unknown'}); the demos tolerate not-ready", file=out)

    # 3. RuntimeClass scone-dev
    handler = runner.kube(["get", "runtimeclass", "scone-dev", "-o", "jsonpath={.handler}"], query="runtimeclass")
    if handler == "":
        runner.kube(["apply", "--server-side", "--field-manager=sptd-integration", "-f", "-"], stdin=RUNTIME_CLASS)
    elif handler != "scone-dev":
        raise Refused(f"RuntimeClass scone-dev exists with handler {handler!r}")

    # 4. the signed set
    state, installed, installed_plans = node_state(runner, manifest)
    print(f"node set state: {state} (installed registry {installed})", file=out)
    if state == "foreign":
        if not args.clear:
            raise Refused("the node holds another registry/plan set; --clear moves /etc/scone/scone-dev aside "
                          "(an operator step) before a fresh install")
        moved = f"/root/scone-dev.moved-{installed[7:19] if installed.startswith('sha256:') else 'unknown'}"
        runner.host(f"test ! -e {moved} && mv {TARGET} {moved}")  # containerd restarts after the install
        state = "fresh"
    staging = f"/root/sptd-node-set-{manifest['artifactSetSha256'][7:19]}"
    changed = False
    if state == "same":
        print("the node already holds this set; nothing to install", file=out)
    else:
        runner.host_copy(args.set, "node-set", staging)
        base = [HELPER, "provision-dev-registry", "--from", f"{staging}/node-set", "--root-pin", pin]
        if state == "earlier":
            base.append("--append")
        runner.host(" ".join(shlex.quote(a) for a in base))  # verify only, writes nothing
        runner.host(" ".join(shlex.quote(a) for a in base + ["--confirm"]))
        changed = True

    # 5. containerd reads the set only at start
    if changed:
        runner.host("systemctl restart containerd.service")
    after = runner.host(f"printf 'sha256:'; sha256sum {TARGET}/profile-registry.json | cut -d' ' -f1", query="after")
    if after != manifest["registry"]["sha256"]:
        raise Refused(f"installed registry is {after}, expected {manifest['registry']['sha256']}")
    print(f"{'dry run, nothing done: ' if runner.dry_run else ''}node {args.node} holds artifact set "
          f"{manifest['artifactSetSha256']} "
          f"({'changed' if changed else 'unchanged'})", file=out)
    return {"state": state, "changed": changed}


def main(argv=None):
    parser = argparse.ArgumentParser(prog="provision_dev_node.py", description=__doc__.splitlines()[0])
    parser.add_argument("--set", required=True, help="artifact-set directory (holds manifest.json and node-set/)")
    parser.add_argument("--expect-hash", required=True, help="pinned artifact-set hash sha256:<hex>")
    parser.add_argument("--node", required=True, help="Kubernetes node name")
    parser.add_argument("--host-exec", default="", help='command prefix for host actions, e.g. "ssh root@node"')
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument("--archive", help="node component archive to check locally")
    parser.add_argument("--archive-sha256")
    parser.add_argument("--helper-sha256", help="pin of the installed sptd-k8s-node helper")
    parser.add_argument("--clear", action="store_true", help="move another installed set aside (never deleted)")
    parser.add_argument("--allow-stand-in", action="store_true", help="accept a stand-in set (dry runs, tests)")
    parser.add_argument("--dry-run", action="store_true", help="print every kubectl and host action; run nothing")
    parser.add_argument("--assume-state", choices=STATES, default="fresh",
                        help="dry run: node state to assume for the queries (default fresh)")
    args = parser.parse_args(argv)
    if bool(args.archive) != bool(args.archive_sha256):
        parser.error("--archive and --archive-sha256 go together")
    try:
        manifest = si.load_json(os.path.join(args.set, "manifest.json"))
        runner = Runner(args.host_exec, args.kubectl, args.dry_run,
                        assumed(args.assume_state, manifest) if args.dry_run else None)
        provision(args, runner)
        return 0
    except (Refused, si.Invalid, OSError, ValueError, KeyError) as error:
        print(f"provision_dev_node.py: refused: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
