#!/usr/bin/env bash
# Point every demo at a registry you can push to, e.g. the in-cluster registry
# from workshop/local-registry.yaml. Rewrites the image names in */Values.yaml.
#
#   ./scripts/use-registry.sh                    # localhost:30500
#   ./scripts/use-registry.sh myreg.example.com/me
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}/.."

target="${1:-localhost:30500}"
source_prefix="${SOURCE_PREFIX:-registry.scontain.com/k8s-scone-images}"

for values in */Values.yaml; do
  if grep -q "${source_prefix}/" "${values}"; then
    sed -i.bak "s#${source_prefix}/#${target}/k8s-scone-images/#g" "${values}"
    rm -f "${values}.bak"
    echo "Updated ${values}"
  fi
done

echo "Demo images now push to ${target}/k8s-scone-images/."
echo "Base images are still pulled from registry.scontain.com, so keep your pull secret."
