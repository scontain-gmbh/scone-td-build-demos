#!/usr/bin/env bash
# The sptd policy templates must pass rust-envcas f69a0a61's launch-contract validation before scone-td-dev-compile
# adds anything (scone-td-dev-compile.rs: ProcessTdLaunchContractV1::from_json_str on the raw template). This checks
# the rules that template edits can break, mirroring envcas-model validation.rs:
#   - inheritedFileDescriptors is exactly 0, 1, 2 plus the declared descriptor files plus, for a script executable,
#     the script descriptor: the highest free number in 3..=255 other than the init-control descriptor 18 (model.rs
#     script_descriptor_number); with no descriptor files that is 255;
#   - a script interpreter is CPython, pins -I, uses only allowlisted options, and denies LD_, GCONV_PATH, OPENSSL_
#     and GLIBC_TUNABLES (at most 32 prefixes of letters, digits and '_').
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -I - "$repo_root/scripts/sptd/policies" <<'PY'
import glob, json, os, re, sys

ALLOWED_ARGS = {"-I", "-B", "-S", "-E", "-s", "-P", "-u", "-O", "-OO", "-q", "-b", "-bb", "-Xutf8", "-Xutf8=0",
                "-Xutf8=1", "-Xdev", "-Xfrozen_modules=on", "-Wignore", "-Wdefault", "-Werror", "-Walways",
                "-Wmodule", "-Wonce"}
REQUIRED_DENIED = {"LD_", "GCONV_PATH", "OPENSSL_", "GLIBC_TUNABLES"}
CPYTHON = re.compile(r"python(3(\.[0-9]+)?)?")
INIT_CONTROL = 18
failures, checked = [], 0
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    doc = json.load(open(path))
    if doc.get("kind") != "ProcessTDLaunchContract":
        continue
    checked += 1
    name = os.path.basename(path)
    process = doc["process"]
    executable = process["expectedExecutable"]["executable"]
    descriptor_files = sorted(e["descriptor"] for e in doc.get("files", {}).get("entries", [])
                              if isinstance(e, dict) and "descriptor" in e)
    want = [0, 1, 2] + descriptor_files
    if executable["type"] == "script":
        free = [n for n in range(255, 2, -1) if n != INIT_CONTROL and n not in descriptor_files]
        want.append(free[0])
        args = executable.get("interpreterArgs", [])
        if not CPYTHON.fullmatch(executable["interpreterPath"].rsplit("/", 1)[-1]):
            failures.append(f"{name}: the script interpreter must be CPython")
        if "-I" not in args or not set(args) <= ALLOWED_ARGS:
            failures.append(f"{name}: interpreterArgs must pin -I and use only allowlisted options: {args}")
        denied = executable.get("deniedEnvironmentPrefixes", [])
        if not REQUIRED_DENIED <= set(denied) or len(denied) > 32 or not all(re.fullmatch(r"[A-Za-z0-9_]{1,64}", p) for p in denied):
            failures.append(f"{name}: deniedEnvironmentPrefixes must include {sorted(REQUIRED_DENIED)} (at most 32 valid prefixes)")
    got = sorted(process["execPolicy"]["inheritedFileDescriptors"])
    if got != sorted(want):
        failures.append(f"{name}: inheritedFileDescriptors {got} must be {sorted(want)}")
if failures or not checked:
    print("FAIL - sptd policy templates the envcas validation refuses:", file=sys.stderr)
    print("\n".join(failures or ["no launch-contract templates found"]), file=sys.stderr)
    sys.exit(1)
print(f"ok - {checked} sptd policy templates pass the envcas descriptor and script rules")
PY
