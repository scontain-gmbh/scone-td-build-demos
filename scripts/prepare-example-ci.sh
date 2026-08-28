#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 --mode <sgx|cvm> [--registry REGISTRY] [--image-pull-secret-name NAME] [--namespace NAMESPACE]

Prepares the example Values.yaml files and Kubernetes pull secrets for CI.

Environment:
  REGISTRY_USER   Registry username used to create the image pull secret.
  REGISTRY_TOKEN  Registry token/password used to create the image pull secret.

Options:
  --mode <mode>              One of: sgx, cvm
  --registry <registry>      Registry hostname to use (default: registry.scontain.com)
  --image-pull-secret-name   Pull secret name to use (default: sconeapps)
  --namespace <namespace>    Kubernetes namespace to deploy all demos into (default: keeps each demo's current value)
  --help                     Show this help message and exit.
USAGE
}

mode=""
registry="${REGISTRY:-registry.scontain.com}"
image_pull_secret_name="${IMAGE_PULL_SECRET_NAME:-sconeapps}"
namespace="${NAMESPACE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --registry)
      registry="${2:-}"
      shift 2
      ;;
    --image-pull-secret-name)
      image_pull_secret_name="${2:-}"
      shift 2
      ;;
    --namespace)
      namespace="${2:-}"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      echo "Error: This script does not accept positional arguments." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Error: This script does not accept positional arguments." >&2
  show_help >&2
  exit 1
fi

case "$mode" in
  sgx|cvm)
    ;;
  *)
    echo "Error: --mode must be either 'sgx' or 'cvm'." >&2
    exit 1
    ;;
esac

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Required command '$command_name' was not found." >&2
    exit 1
  fi
}

upsert_scalar() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN {
      found = 0
      in_environment = 0
    }
    /^environment:[[:space:]]*$/ {
      in_environment = 1
      print
      next
    }
    in_environment && $0 ~ ("^  " key ":") {
      print "  " key ": " value
      found = 1
      next
    }
    in_environment && $0 !~ /^  / {
      if (!found) {
        print "  " key ": " value
      }
      in_environment = 0
    }
    { print }
    END {
      if (in_environment && !found) {
        print "  " key ": " value
      }
    }
  ' "$file" >"$tmp_file"
  mv "$tmp_file" "$file"
}

ensure_namespace() {
  local namespace="$1"
  if [[ "$namespace" == "default" ]]; then
    return 0
  fi

  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
}

apply_pull_secret() {
  local namespace="$1"

  kubectl create secret docker-registry "$image_pull_secret_name" \
    --namespace "$namespace" \
    --docker-server="$registry" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
}

require_command kubectl
require_command awk

if [[ -z "${REGISTRY_USER:-}" ]]; then
  echo "Error: REGISTRY_USER must be set in the environment." >&2
  exit 1
fi

if [[ -z "${REGISTRY_TOKEN:-}" ]]; then
  echo "Error: REGISTRY_TOKEN must be set in the environment." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

all_values_files=(
  "${repo_root}/hello-world/Values.yaml"
  "${repo_root}/configmap/Values.yaml"
  "${repo_root}/web-server/Values.yaml"
  "${repo_root}/network-policy/Values.yaml"
  "${repo_root}/go-args-env-file/Values.yaml"
  "${repo_root}/flask-redis/Values.yaml"
  "${repo_root}/flask-redis-netshield/Values.yaml"
  "${repo_root}/java-args-env-file/Values.yaml"
  "${repo_root}/software-updates/Values.yaml"
  "${repo_root}/image-signing/Values.yaml"
)

# tee-type replaced the old cvm boolean, so the migrated demos consume SCONE_ENCLAVE as a
# boolean value. image-signing (added upstream) still ships the flag-style SCONE_ENCLAVE,
# so it is overridden after the shared loop below.
flag_mode_files=(
  "${repo_root}/image-signing/Values.yaml"
)
if [[ "$mode" == "sgx" ]]; then
  tee_type="sgx"
  scone_enclave="'false'"
  flag_scone_enclave="''"
  flag_cvm_mode="''"
else
  tee_type="cvm"
  scone_enclave="'true'"
  flag_scone_enclave="--scone-enclave"
  flag_cvm_mode="--cvm"
fi

for values_file in "${all_values_files[@]}"; do
  upsert_scalar "$values_file" "TEE_TYPE" "$tee_type"
  upsert_scalar "$values_file" "SCONE_ENCLAVE" "$scone_enclave"
  upsert_scalar "$values_file" "IMAGE_PULL_SECRET_NAME" "$image_pull_secret_name"
  upsert_scalar "$values_file" "REGISTRY" "$registry"
  if [[ -n "$namespace" ]]; then
    upsert_scalar "$values_file" "NAMESPACE" "$namespace"
  fi
  if [[ -n "${CAS_NAME:-}" ]]; then
    upsert_scalar "$values_file" "CAS_NAME" "$CAS_NAME"
  fi
  if [[ -n "${CAS_NAMESPACE:-}" ]]; then
    upsert_scalar "$values_file" "CAS_NAMESPACE" "$CAS_NAMESPACE"
  fi
  # CAS_ENDPOINT is the address the manifest targets. Keep it in sync with the in-cluster
  # CAS (CAS_NAME.CAS_NAMESPACE) so changing the CAS name or namespace does not leave the
  # manifest pointed at a stale endpoint. Set CAS_ENDPOINT explicitly to run against an
  # external CAS, e.g. edge.scone-cas.cf.
  if [[ -n "${CAS_ENDPOINT:-}" ]]; then
    upsert_scalar "$values_file" "CAS_ENDPOINT" "$CAS_ENDPOINT"
  else
    eff_cas_name="$(awk -F': ' '/^  CAS_NAME:/ { gsub(/["'\''[:space:]]/, "", $2); print $2; exit }' "$values_file")"
    eff_cas_namespace="$(awk -F': ' '/^  CAS_NAMESPACE:/ { gsub(/["'\''[:space:]]/, "", $2); print $2; exit }' "$values_file")"
    if [[ -n "$eff_cas_name" && -n "$eff_cas_namespace" ]]; then
      upsert_scalar "$values_file" "CAS_ENDPOINT" "${eff_cas_name}.${eff_cas_namespace}"
    fi
  fi
done

# image-signing still uses the flag-style SCONE_ENCLAVE and CVM_MODE (it passes --cvm into
# `scone-td-build register`), so override the boolean/tee-type set above; otherwise the CVM
# sweep would leave it on the SGX path.
for values_file in "${flag_mode_files[@]}"; do
  upsert_scalar "$values_file" "SCONE_ENCLAVE" "$flag_scone_enclave"
  upsert_scalar "$values_file" "CVM_MODE" "$flag_cvm_mode"
done

declare -A seen_namespaces=()
target_namespaces=("default")

for values_file in "${all_values_files[@]}"; do
  ns="$(awk -F': ' '/^  NAMESPACE:/ { gsub(/["'\''[:space:]]/, "", $2); print $2; exit }' "$values_file")"
  if [[ -n "$ns" && -z "${seen_namespaces[$ns]:-}" ]]; then
    seen_namespaces["$ns"]=1
    target_namespaces+=("$ns")
  fi
done

for ns in "${target_namespaces[@]}"; do
  ensure_namespace "$ns"
  apply_pull_secret "$ns"
done

printf 'Prepared example CI configuration for mode: %s\n' "$mode"
printf 'Registry: %s\n' "$registry"
printf 'Image pull secret: %s\n' "$image_pull_secret_name"
if [[ -n "$namespace" ]]; then
  printf 'Namespace (applied to all demos): %s\n' "$namespace"
fi
printf 'Namespaces:\n'
for ns in "${target_namespaces[@]}"; do
  printf '  - %s\n' "$ns"
done
