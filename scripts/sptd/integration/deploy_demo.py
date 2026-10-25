#!/usr/bin/env python3
"""Deploy-only sptd demo run from a pinned artifact set (docs/sptd-integration.md). NON_RELEASE.

  deploy_demo.py --set DIR --expect-hash sha256:... --node NAME --image-digest sha256:...
                 [--demos a,b] [--namespace NS] [--report FILE] [--skip-native] [--dry-run]

For every selected step of the set, in catalog order:

  1. native     apply the rendered native manifests, wait, run the demo checks, delete
  2. confidential  apply the support manifests and the confidential output manifest; every
                Pod of the step must become Ready (or Succeeded for Jobs/bare Pods)
  3. check      the demo's own checks (demos.json "deploy": logs regex or HTTP through
                kubectl port-forward, which also reaches a hostNetwork Pod)
  4. cleanup    delete what the step applied and wait until its Pods are gone; this runs
                even when an earlier stage failed

It onboards nothing, signs nothing and needs no key: the node must already hold the set
(provision_dev_node.py). --dry-run prints every kubectl action and runs none.
"""
import argparse
import json
import os
import re
import shlex
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sptdinteg as si  # noqa: E402
import artifact_manifest  # noqa: E402


class Failed(Exception):
    pass


class Kube:
    def __init__(self, kubectl, namespace, dry_run, timeout, out=None):
        self.base = shlex.split(kubectl)
        self.ns = namespace
        self.dry_run = dry_run
        self.timeout = timeout
        self.out = out or sys.stdout
        self.actions = []

    def run(self, args, check=True, ns=True):
        argv = self.base + (["-n", self.ns] if ns else []) + args
        text = " ".join(shlex.quote(a) for a in argv)
        self.actions.append(text)
        print(("[dry-run] kubectl: " if self.dry_run else "kubectl: ") + text, file=self.out, flush=True)
        if self.dry_run:
            return ""
        result = subprocess.run(argv, capture_output=True, text=True)
        if check and result.returncode:
            raise Failed(f"{text}: {result.stderr.strip()[-400:]}")
        return result.stdout

    def wait(self, selector, mode):
        if mode == "ready":
            self.run(["wait", "--for=condition=Ready", "pod", "-l", selector, f"--timeout={self.timeout}s"])
            return
        # completed: Jobs and bare Pods end in Succeeded; Ready may never be observed.
        deadline = time.time() + self.timeout
        while True:
            phases = self.run(["get", "pods", "-l", selector, "-o", "jsonpath={.items[*].status.phase}"]).split()
            if self.dry_run or (phases and all(p == "Succeeded" for p in phases)):
                return
            if "Failed" in phases:
                raise Failed(f"a Pod of {selector} failed")
            if time.time() > deadline:
                raise Failed(f"Pods of {selector} did not complete in {self.timeout}s (phases {phases})")
            time.sleep(3)

    def logs(self, selector, container=None):
        args = ["logs", "-l", selector, "--tail=-1", "--prefix"] + (["-c", container] if container else [])
        return self.run(args)

    def http(self, selector, port, path, scheme="http", insecure=False, retries=20):
        name = self.run(["get", "pods", "-l", selector, "-o", "jsonpath={.items[0].metadata.name}"]).strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            local = probe.getsockname()[1]
        argv = self.base + ["-n", self.ns, "port-forward", f"pod/{name or '<pod>'}", f"{local}:{port}"]
        text = " ".join(shlex.quote(a) for a in argv)
        self.actions.append(text)
        url = f"{scheme}://127.0.0.1:{local}{path}"
        print(("[dry-run] kubectl: " if self.dry_run else "kubectl: ") + text + f"  then GET {url}",
              file=self.out, flush=True)
        if self.dry_run:
            return
        forward = subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            context = None
            if insecure:
                import ssl
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
            last = None
            for _ in range(retries):
                try:
                    with urllib.request.urlopen(url, timeout=10, context=context) as response:
                        if 200 <= response.status < 300:
                            return
                        last = f"HTTP {response.status}"
                except (urllib.error.URLError, OSError) as error:
                    last = str(error)
                time.sleep(3)
            raise Failed(f"GET {path} on {selector}:{port} failed: {last}")
        finally:
            forward.terminate()
            forward.wait(timeout=10)


def run_checks(kube, deploy):
    for check in deploy["checks"]:
        if check["type"] == "logs":
            text = kube.logs(check["selector"], check.get("container"))
            if not kube.dry_run and not re.search(check["regex"], text):
                raise Failed(f"logs of {check['selector']} do not match {check['regex']!r}")
        elif check["type"] == "http":
            selector = check.get("selector") or deploy["wait"][0]["selector"]
            kube.http(selector, check["port"], check["path"], check.get("scheme", "http"), check.get("insecure", False))
        else:
            raise Failed(f"unknown check type {check['type']}")


def stage(kube, files, deploy, set_dir):
    for rel in files:
        kube.run(["apply", "-f", os.path.join(set_dir, rel)])
    for item in deploy["wait"]:
        kube.wait(item["selector"], item["for"])


def cleanup(kube, files, deploy, set_dir):
    for rel in reversed(files):
        kube.run(["delete", "--ignore-not-found", "--wait=true", "-f", os.path.join(set_dir, rel)], check=False)
    for item in deploy["wait"]:
        kube.run(["wait", "--for=delete", "pod", "-l", item["selector"], f"--timeout={kube.timeout}s"], check=False)


def run_step(kube, step, catalog_step, set_dir, skip_native):
    deploy = catalog_step["deploy"]
    ok = "DRY-RUN" if kube.dry_run else "PASS"  # a dry run proves nothing about the demo
    result = {"step": step["id"], "native": "SKIPPED" if skip_native else None, "confidentialReady": None,
              "check": None, "cleanup": None}
    supports = step.get("supportManifests", [])
    if not skip_native:
        try:
            stage(kube, step["nativeManifests"], deploy, set_dir)
            run_checks(kube, deploy)
            result["native"] = ok
        except Failed as error:
            result["native"] = f"FAIL: {error}"
        finally:
            cleanup(kube, step["nativeManifests"], deploy, set_dir)
        if result["native"] != ok:
            return result
    applied = supports + [step["outputManifest"]]
    try:
        try:
            stage(kube, applied, deploy, set_dir)
            result["confidentialReady"] = ok
        except Failed as error:
            result["confidentialReady"] = f"FAIL: {error}"
            return result
        try:
            run_checks(kube, deploy)
            result["check"] = ok
        except Failed as error:
            result["check"] = f"FAIL: {error}"
    finally:
        cleanup(kube, applied, deploy, set_dir)
        result["cleanup"] = "DONE"
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(prog="deploy_demo.py", description=__doc__.splitlines()[0])
    parser.add_argument("--set", required=True)
    parser.add_argument("--expect-hash", required=True)
    parser.add_argument("--node", required=True)
    parser.add_argument("--image-digest", required=True, help="node image digest the set was onboarded for")
    parser.add_argument("--demos", default="", help="comma-separated subset (default: every demo in the set)")
    parser.add_argument("--namespace", help="default: the namespace the set was rendered for")
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--skip-native", action="store_true")
    parser.add_argument("--report", help="write the per-step results as JSON")
    parser.add_argument("--allow-stand-in", action="store_true")
    parser.add_argument("--dry-run", action="store_true", help="print every kubectl action; run nothing")
    args = parser.parse_args(argv)
    try:
        manifest = si.load_json(os.path.join(args.set, "manifest.json"))
        artifact_manifest.validate(manifest, set_dir=args.set, expect_hash=args.expect_hash,
                                   allow_stand_in=args.allow_stand_in)
        if manifest["facts"]["nodeImageDigest"] != args.image_digest:
            raise si.Invalid(f"the set was onboarded for node image {manifest['facts']['nodeImageDigest']}, "
                             f"not {args.image_digest}")
        if manifest["nodeName"] not in (None, args.node):
            raise si.Invalid(f"the set was onboarded for node {manifest['nodeName']}, not {args.node}")
        namespace = args.namespace or manifest["namespace"]
        if manifest["podPlans"] and namespace != manifest["namespace"]:
            raise si.Invalid(f"the Pod plans bind namespace {manifest['namespace']}")
        catalog = {s["id"]: s for s in si.load_catalog()["steps"]}
        wanted = [d for d in args.demos.split(",") if d]
        present = [d["demo"] for d in manifest["demos"]]
        missing = sorted(set(wanted) - set(present))
        if missing:
            raise si.Invalid("demos not in the artifact set: " + ", ".join(missing))
        kube = Kube(args.kubectl, namespace, args.dry_run, args.timeout)
        results = []
        for demo in manifest["demos"]:
            if wanted and demo["demo"] not in wanted:
                continue
            for step in demo["steps"]:
                print(f"== {step['id']}", flush=True)
                results.append(run_step(kube, step, catalog[step["id"]], args.set, args.skip_native))
    except (si.Invalid, OSError, ValueError, KeyError) as error:
        print(f"deploy_demo.py: refused: {error}", file=sys.stderr)
        return 1
    ok = "DRY-RUN" if args.dry_run else "PASS"
    passed = all(r["native"] in (ok, "SKIPPED") and r["confidentialReady"] == ok and r["check"] == ok
                 for r in results)
    report = {"artifactSetSha256": manifest["artifactSetSha256"], "node": args.node, "dryRun": args.dry_run,
              "results": results, "passed": passed}
    if args.report:
        with open(args.report, "w") as handle:
            json.dump(report, handle, indent=2, sort_keys=True)
            handle.write("\n")
    for r in results:
        print(f"{r['step']:24s} native={r['native']} ready={r['confidentialReady']} check={r['check']} "
              f"cleanup={r['cleanup']}")
    return 0 if passed else 2


if __name__ == "__main__":
    sys.exit(main())
