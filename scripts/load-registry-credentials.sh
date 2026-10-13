#!/usr/bin/env bash
# Source the credentials mounted by the SCONE toolbox, when available.
load_toolbox_registry_credentials() {
  local credentials_file="${SCONE_REGISTRY_ENV_FILE:-/scone-registry/scone-registry-env}"
  if [[ -r "$credentials_file" ]]; then
    # shellcheck source=/dev/null
    source "$credentials_file"
  elif [[ -n "${SCONE_REGISTRY_ENV_FILE:-}" ]]; then
    echo "Cannot read configured SCONE registry credential file: $credentials_file" >&2
    return 1
  fi
}
load_toolbox_registry_credentials
unset -f load_toolbox_registry_credentials
