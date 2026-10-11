#!/usr/bin/env bash
# Free disk space between demos on a small cluster: remove unused images and
# build cache from the Docker engine, and optionally empty the in-cluster
# registry from workshop/local-registry.yaml by restarting it.
#
#   ./scripts/prune-demo-images.sh             # Docker engine only
#   ./scripts/prune-demo-images.sh --registry  # also empty the registry
set -euo pipefail

docker system prune -af
docker builder prune -af

if [[ "${1:-}" == "--registry" ]]; then
  ns="${REGISTRY_NAMESPACE:-registry}"
  kubectl -n "${ns}" rollout restart deployment/registry
  kubectl -n "${ns}" rollout status deployment/registry --timeout=120s
  echo "Registry in namespace ${ns} restarted; all pushed demo images are gone."
fi
