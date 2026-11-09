#!/usr/bin/env bash
# Check that the tools the demos need are installed, before running any demo.
set -euo pipefail

MIN_TD_BUILD_VERSION="${MIN_TD_BUILD_VERSION:-0.5.0}"
missing=0

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' is not installed. $2" >&2
    missing=1
  fi
}

want() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "WARNING: '$1' is not installed. $2" >&2
  fi
}

need kubectl "Install kubectl."
need docker "The demos build and push container images."
need tplenv "Run: cargo install tplenv"
need retry-spinner "Run: cargo install retry-spinner"
need scone-td-build "Install scone-td-build ${MIN_TD_BUILD_VERSION} or newer."
want skopeo "Only the image-signing demo needs it."
want cosign "Only the image-signing demo needs it."

if command -v scone-td-build >/dev/null 2>&1; then
  version="$(scone-td-build --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
  if [[ -z "${version}" ]]; then
    echo "ERROR: could not read the version of scone-td-build." >&2
    missing=1
  elif [[ "$(printf '%s\n%s\n' "${MIN_TD_BUILD_VERSION}" "${version}" | sort -V | head -n1)" != "${MIN_TD_BUILD_VERSION}" ]]; then
    echo "ERROR: scone-td-build ${version} is too old; the demos need ${MIN_TD_BUILD_VERSION} or newer." >&2
    echo "       Older versions fail with: required arguments were not provided: --cas-address" >&2
    missing=1
  else
    echo "scone-td-build ${version} OK"
  fi
fi

exit "${missing}"
