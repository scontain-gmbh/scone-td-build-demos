#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 --mode <sgx|cvm> [--registry REGISTRY] [--image-pull-secret-name NAME] [--namespace NAMESPACE] [--scone-cas-addr ADDR]

Prepares the example Values.yaml files (seeded from values.template.yaml when
missing) and Kubernetes pull secrets for CI.

Environment:
  REGISTRY_USER   Registry username used to create the image pull secret.
  REGISTRY_TOKEN  Registry token/password used to create the image pull secret.
  SCONE_CAS_ADDR  CAS address to write into every Values.yaml (default: keeps each demo's current value).

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
scone_cas_addr="${SCONE_CAS_ADDR:-}"

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
    --scone-cas-addr)
      scone_cas_addr="${2:-}"
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
    in_environment && $0 ~ /^[[:space:]]*(#.*)?$/ {
      # Blank and comment lines do not end the environment block.
      print
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
  "${repo_root}/demos/hello-world/Values.yaml"
  "${repo_root}/demos/configmap/Values.yaml"
  "${repo_root}/demos/web-server/Values.yaml"
  "${repo_root}/demos/network-policy/Values.yaml"
  "${repo_root}/demos/go-args-env-file/Values.yaml"
  "${repo_root}/demos/flask-redis/Values.yaml"
  "${repo_root}/demos/flask-redis-netshield/Values.yaml"
  "${repo_root}/demos/java-args-env-file/Values.yaml"
  "${repo_root}/demos/software-updates/Values.yaml"
  "${repo_root}/demos/image-signing/Values.yaml"
  "${repo_root}/demos/pet-clinic/Values.yaml"
)

if [[ "$mode" == "sgx" ]]; then
  boolean_cvm_mode="'false'"
  boolean_scone_enclave="'false'"
else
  boolean_cvm_mode="'true'"
  boolean_scone_enclave="'true'"
fi


for values_file in "${all_values_files[@]}"; do
  # Values.yaml is not tracked in git; the demos seed it from values.template.yaml
  # on their first run. Do the same here so the upserts below have a file to edit.
  if [[ ! -f "$values_file" ]]; then
    values_template="$(dirname "$values_file")/values.template.yaml"
    if [[ ! -f "$values_template" ]]; then
      echo "Error: Neither '$values_file' nor '$values_template' exists." >&2
      exit 1
    fi
    cp "$values_template" "$values_file"
  fi
  upsert_scalar "$values_file" "CVM_MODE" "$boolean_cvm_mode"
  upsert_scalar "$values_file" "SCONE_ENCLAVE" "$boolean_scone_enclave"
  upsert_scalar "$values_file" "IMAGE_PULL_SECRET_NAME" "$image_pull_secret_name"
  upsert_scalar "$values_file" "REGISTRY" "$registry"
  if [[ -n "$scone_cas_addr" ]]; then
    upsert_scalar "$values_file" "SCONE_CAS_ADDR" "$scone_cas_addr"
  fi

  if [[ -n "$namespace" ]]; then
    upsert_scalar "$values_file" "NAMESPACE" "$namespace"
  fi
done

declare -A seen_namespaces=()
target_namespaces=("default")

for values_file in "${all_values_files[@]}"; do
  NAMESPACE="$(awk -F': ' '/^  NAMESPACE:/ { gsub(/["'\''[:space:]]/, "", $2); print $2; exit }' "$values_file")"
  if [[ -n "$NAMESPACE" && -z "${seen_namespaces[$NAMESPACE]:-}" ]]; then
    seen_namespaces["$NAMESPACE"]=1
    target_namespaces+=("$NAMESPACE")
  fi
done

for NAMESPACE in "${target_namespaces[@]}"; do
  ensure_namespace "$NAMESPACE"
  apply_pull_secret "$NAMESPACE"
done

printf 'Prepared example CI configuration for mode: %s\n' "$mode"
printf 'Registry: %s\n' "$registry"
printf 'Image pull secret: %s\n' "$image_pull_secret_name"
if [[ -n "$namespace" ]]; then
  printf 'Namespace (applied to all demos): %s\n' "$namespace"
fi
printf 'Namespaces:\n'
for NAMESPACE in "${target_namespaces[@]}"; do
  printf '  - %s\n' "$NAMESPACE"
done
