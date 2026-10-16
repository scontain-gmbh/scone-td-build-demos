#!/usr/bin/env bash
# The toolbox service account may not read every resource that `kubectl get all` lists.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `all` also covers provider CRDs in the `all` category (s3buckets and s3users on
# Gardener), which the toolbox account cannot list, so the demo fails on them.
if matches="$(grep -n 'kubectl get all' "$repo_root"/*/README.md)"; then
  echo 'FAIL - demos list `kubectl get all`, which the toolbox account may not read:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi
printf 'ok - demos list only the kinds they create\n'
