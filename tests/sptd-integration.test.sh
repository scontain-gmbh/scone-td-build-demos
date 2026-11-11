#!/usr/bin/env bash
# sptd integration scripts (scripts/sptd/integration): re-onboard plan, artifact manifest,
# node provisioning and deploy dry runs. Standard-library Python only; no cluster, no key.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -B "$repo_root/scripts/sptd/integration/tests/test_integration.py"
