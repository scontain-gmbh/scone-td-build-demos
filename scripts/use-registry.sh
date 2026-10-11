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

# skopeo (image-signing demo) refuses plain HTTP unless the registry is marked insecure.
case "${target}" in
  localhost:*|127.0.0.1:*)
    registry_host="${target%%/*}"
    conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/containers"
    conf="${conf_dir}/registries.conf"
    if ! grep -qs "location = \"${registry_host}\"" "${conf}"; then
      mkdir -p "${conf_dir}"
      printf '\n[[registry]]\nlocation = "%s"\ninsecure = true\n' "${registry_host}" >> "${conf}"
      echo "Marked ${registry_host} insecure for skopeo in ${conf}"
    fi
    ;;
esac

echo "Demo images now push to ${target}/k8s-scone-images/."
echo "Base images are still pulled from registry.scontain.com, so keep your pull secret."
