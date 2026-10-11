#!/usr/bin/env bash
# Pull every public base image the demos build from into the Docker engine
# ahead of time, so a room full of participants does not hit Docker Hub
# rate limits or pull timeouts during the demos (see issue #33).
#
#   ./scripts/prepull-base-images.sh            # pull
#   ./scripts/prepull-base-images.sh --list     # only print the images
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}/.."

# FROM lines in Dockerfiles and in Dockerfiles embedded in the READMEs, plus the
# unprotected images passed to scone-td-build register. Skip templated names.
# A read loop instead of mapfile keeps this working with the Bash 3.2 of macOS.
images=()
while IFS= read -r image; do
  [[ -n "${image}" ]] && images+=("${image}")
done < <(
  {
    grep -rhoE '^[[:space:]]*FROM[[:space:]]+[^[:space:]]+' --include='Dockerfile*' --include='*.md' . \
      | awk '{print $2}'
    grep -rhoE --include='*.md' -e '--unprotected-image[= ]+[^[:space:]\\]+' . \
      | awk '{print $NF}'
  } | grep -v '[$]' | sort -u
)

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${images[@]}"
  exit 0
fi

failed=()
for image in "${images[@]}"; do
  echo "Pulling ${image}"
  pulled=false
  for attempt in 1 2 3; do
    if docker pull --quiet "${image}"; then
      pulled=true
      break
    fi
    echo "  attempt ${attempt} failed, retrying in $((attempt * 10))s"
    sleep $((attempt * 10))
  done
  [[ "${pulled}" == "true" ]] || failed+=("${image}")
done

if (( ${#failed[@]} > 0 )); then
  echo "ERROR: could not pull: ${failed[*]}" >&2
  exit 1
fi
echo "All ${#images[@]} base images are cached."
