#!/usr/bin/env bash
# Remove the confidential MariaDB variant. Namespace comes from ../Values.yaml
# (no flags).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DEMO_DIR="$SCRIPT_DIR/../../pet-clinic/"


export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --eval-export-values --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)"

echo "==> helm uninstall mariadb"
helm uninstall mariadb -n "$NAMESPACE" 2>/dev/null || true

echo "==> delete mariadb-spr PVCs"
kubectl -n "$NAMESPACE" get pvc -o name 2>/dev/null | grep -i mariadb | xargs -r kubectl -n "$NAMESPACE" delete >/dev/null 2>&1 || true

echo "==> Done. (Signed sessions created on the CAS are left in place.)"
