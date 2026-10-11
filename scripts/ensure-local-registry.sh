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

if [[ -z "${owners}" ]]; then
  echo "NodePort ${node_port} is free; creating the workshop registry."
  kubectl apply -f "${script_dir}/../workshop/local-registry.yaml"
  exit 0
fi

ns_name_port="${owners%%$'\n'*}"
svc_port="${ns_name_port##*/}"
ns="${ns_name_port%%/*}"
name="${ns_name_port#*/}"; name="${name%/*}"

# A Docker registry answers GET /v2/ with 200 (or 401 when it needs a login).
if kubectl get --raw "/api/v1/namespaces/${ns}/services/${name}:${svc_port}/proxy/v2/" >/dev/null 2>&1; then
  echo "Reusing the registry ${ns}/${name} on NodePort ${node_port}."
  exit 0
fi

echo "ERROR: NodePort ${node_port} belongs to ${ns}/${name}, which is not a Docker registry." >&2
echo "       Free the port, or set nodePort in workshop/local-registry.yaml and use that port everywhere." >&2
exit 1
