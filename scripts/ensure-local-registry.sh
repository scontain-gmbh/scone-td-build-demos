#!/usr/bin/env bash
# Make sure a Docker registry serves NodePort 30500 for the workshop flow:
# reuse an existing registry on that port, create workshop/local-registry.yaml
# if the port is free, and stop if an unrelated service already holds it.
#
#   ./scripts/ensure-local-registry.sh
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node_port="${NODE_PORT:-30500}"

# namespace/name/port of every service that exposes the NodePort
owners="$(kubectl get svc -A -o jsonpath='{range .items[*]}{range .spec.ports[*]}{.nodePort}{" "}{.port}{" "}{end}{"|"}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' \
  | awk -F'|' -v np="${node_port}" '{n=split($1,f," "); for(i=1;i<n;i+=2) if (f[i]==np) print $2 "/" f[i+1]}')"

# Prints "yes" when the service answers the registry API: GET /v2/ returns 200, or
# 401 when the registry needs a login (kubectl reports that as an error).
is_registry() {
  local out
  if out="$(kubectl get --raw "/api/v1/namespaces/$1/services/$2:$3/proxy/v2/" 2>&1)"; then
    echo yes
  elif [[ "${out}" == *Unauthorized* || "${out}" == *401* ]]; then
    echo yes
  else
    echo no
  fi
}

if [[ -z "${owners}" ]]; then
  echo "NodePort ${node_port} is free; creating the workshop registry."
  kubectl apply -f "${script_dir}/../workshop/local-registry.yaml"
  kubectl -n registry rollout status deployment/registry --timeout="${READY_TIMEOUT:-180}s"
  # The pod can be Ready a moment before the service routes to it.
  for _ in $(seq 1 30); do
    if [[ "$(is_registry registry registry 5000)" == yes ]]; then
      echo "Registry registry/registry is serving on NodePort ${node_port}."
      exit 0
    fi
    sleep 2
  done
  echo "ERROR: the workshop registry did not answer /v2/ in time." >&2
  exit 1
fi

ns_name_port="${owners%%$'\n'*}"
svc_port="${ns_name_port##*/}"
ns="${ns_name_port%%/*}"
name="${ns_name_port#*/}"; name="${name%/*}"

if [[ "$(is_registry "${ns}" "${name}" "${svc_port}")" == yes ]]; then
  echo "Reusing the registry ${ns}/${name} on NodePort ${node_port}."
  exit 0
fi

echo "ERROR: NodePort ${node_port} belongs to ${ns}/${name}, which is not a Docker registry." >&2
echo "       Free the port, or set nodePort in workshop/local-registry.yaml and use that port everywhere." >&2
exit 1
