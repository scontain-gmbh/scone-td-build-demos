#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs a demo-style shell script generated from pet-clinic/README.md.

Options:
  --help             Show this help message and exit.
  --non-interactive  Do not force confirmation for existing tplenv values.
USAGE
}

NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true
      shift
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

unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "%b" "$LILAC"
printf '%s\n' '# pet-clinic (Spring Boot + MariaDB)'
printf '%s\n' ''
printf '%s\n' 'This demo runs the upstream [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application confidentially inside an Intel SGX enclave using SCONE, backed by a native MariaDB. The Java application (JVM, heap, and the JDBC credentials it uses) is protected inside the enclave and attests to a CAS before it starts; the database runs as a normal Kubernetes workload next to it.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Architecture'
printf '%s\n' ''
printf '%s\n' '| Component | Mode | Notes |'
printf '%s\n' '| --- | --- | --- |'
printf '%s\n' '| PetClinic (Spring Boot / JVM) | Confidential (SGX + SCONE) | `java` is the enforced binary; the whole JVM runtime is sconified and attests to the CAS. |'
printf '%s\n' '| MariaDB | Native | Deployed directly with `kubectl`, outside the register/apply flow. |'
printf '%s\n' '| PetClinic ↔ MariaDB | In-cluster TCP | The confidential app opens a JDBC connection from inside the enclave. |'
printf '%s\n' ''
printf '%s\n' 'Only PetClinic is confidential. MariaDB is intentionally native: it keeps its standard entrypoint and initialisation, which the confidential-conversion flow does not need to touch.'
printf '%s\n' ''
printf '%s\n' '## Project layout'
printf '%s\n' ''
printf '%s\n' '.'
printf '%s\n' '├── Dockerfile                  # multi-stage build of PetClinic from a pinned upstream commit'
printf '%s\n' '├── environment-variables.md    # tplenv variable definitions'
printf '%s\n' '├── Values.yaml                 # default values'
printf '%s\n' '└── manifests/'
printf '%s\n' '    ├── secret.template.yaml        # database credentials Secret'
printf '%s\n' '    ├── mariadb.template.yaml       # native MariaDB Deployment and Service'
printf '%s\n' '    ├── petclinic.template.yaml     # PetClinic Deployment and Service (apply input)'
printf '%s\n' '    ├── scone.template.yaml         # Register + Apply manifest for scone-td-build'
printf '%s\n' '    └── manifest.prod.sanitized.yaml    # produced by scone-td-build'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX support and the SCONE stack installed (operator, LAS, and a CAS)'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- Docker (with push access to your registry)'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native PetClinic image'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential (SCONE-protected) image'
printf '%s\n' '- `$PETCLINIC_REF` - Upstream Spring PetClinic commit the image is built from'
printf '%s\n' '- `$MARIADB_IMAGE` - Native MariaDB image (default: `mariadb:11.4`)'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.0.8`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS name (for example, `cas`)'
printf '%s\n' '- `$CAS_ENDPOINT` - Address the manifest targets; keep it in sync with `$CAS_NAME`.`$CAS_NAMESPACE` (default: `cas.default`), or set to an external CAS address to run against one'
printf '%s\n' '- `$TEE_TYPE` - Set to `cvm` for CVM mode or `sgx` for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `true` for confidential nodes, or `false` for Kata Pods'
printf '%s\n' '- `$NAMESPACE` - namespace name (default: `pet-clinic`)'
printf '%s\n' '- `$ENCLAVE_HEAP` - Enclave heap of the PetClinic container (default: `4G`)'
printf '%s\n' '- `$DB_NAME`, `$DB_USER`, `$DB_PASSWORD`, `$DB_ROOT_PASSWORD` - MariaDB database and credentials'
printf '%s\n' ''
printf '%s\n' 'Assume you start in `scone-td-build-demos` and switch into this demo directory:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Change into `pet-clinic`.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
pushd pet-clinic
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove the state file of an earlier run, if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm -f pet-clinic-demo.json || true
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
export SIGNER="$(scone self show-session-signing-key)"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '> **Note:** All commands in the following sections assume these environment variables are exported in your current shell session. If you open a new terminal, re-run the `export SIGNER` and `eval $(tplenv ...)` commands above before proceeding.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 4. Build and Push the Native Image'
printf '%s\n' ''
printf '%s\n' 'The Dockerfile clones Spring PetClinic at `$PETCLINIC_REF`, builds the jar with Maven, and copies it into an `eclipse-temurin:17-jre-noble` runtime image.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Build the container image.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker build --build-arg "PETCLINIC_REF=${PETCLINIC_REF}" -t ${IMAGE_NAME} .
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Push the container image to the registry.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker push ${IMAGE_NAME}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 5. Render the Manifests'
printf '%s\n' ''
printf '%s\n' '`tplenv` substitutes environment variables into the template files and writes the final manifests:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file manifests/secret.template.yaml    --create-values-file --output manifests/secret.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file manifests/mariadb.template.yaml   --create-values-file --output manifests/mariadb.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file manifests/petclinic.template.yaml --create-values-file --output manifests/petclinic.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file manifests/scone.template.yaml     --create-values-file --output manifests/scone.yaml --indent
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 6. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'The pull secret is refreshed with the credentials selected by `tplenv`.'
printf '%s\n' 'Inside the SCONE toolbox, setup loads its mounted registry credentials first.'
printf '%s\n' 'Saved overrides belong in the ignored `Values.credentials.yaml`; empty registry'
printf '%s\n' 'fields in the shared `Values.yaml` must not mask the toolbox credentials.'
printf '%s\n' 'The namespace must already exist when running with the toolbox service account;'
printf '%s\n' '`k8s_cli.sh` provisions the standard demo namespaces and scoped roles.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  if ! kubectl create namespace "$NAMESPACE"; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    echo "Namespace $NAMESPACE is unavailable. Run toolbox setup using a cluster administrator first." >&2
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    exit 1
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  fi
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
source ../scripts/load-registry-credentials.sh
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
read -r -a registry_confirmation_options <<< "${CONFIRM_ALL_ENVIRONMENT_VARIABLES-}"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
registry_values_temporary="$(mktemp Values.credentials.yaml.XXXXXX)"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# The temporary file holds the token; remove it even if this step is interrupted.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
trap 'rm -f "$registry_values_temporary"' EXIT
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if [[ -f Values.credentials.yaml ]]; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  cp -p Values.credentials.yaml "$registry_values_temporary"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if registry_exports="$(tplenv --values "$registry_values_temporary" --file registry.credentials.md --create-values-file --eval "${registry_confirmation_options[@]}")"; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  eval "$registry_exports"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  if [[ -z "${REGISTRY:-}" || -z "${REGISTRY_USER:-}" || -z "${REGISTRY_TOKEN:-}" ]]; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    rm -f "$registry_values_temporary"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    echo "Registry credentials are incomplete. Run this demo interactively or configure Values.credentials.yaml." >&2
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    exit 1
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  fi
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  chmod 600 "$registry_values_temporary"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  mv -f "$registry_values_temporary" Values.credentials.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
else
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  rm -f "$registry_values_temporary"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  exit 1
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
trap - EXIT
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Pass the credentials on stdin: as command-line flags the token would be visible in `ps`.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
registry_auth="$(printf '%s:%s' "$REGISTRY_USER" "$REGISTRY_TOKEN" | base64 | tr -d '\n')"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
printf '{"auths":{"%s":{"username":"%s","password":"%s","auth":"%s"}}}' \
  "$REGISTRY" "$REGISTRY_USER" "$REGISTRY_TOKEN" "$registry_auth" \
  | kubectl create secret generic -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" \
      --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin \
      --dry-run=client -o yaml \
  | kubectl apply -n "$NAMESPACE" -f -
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
unset registry_auth
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 7. Deploy MariaDB'
printf '%s\n' ''
printf '%s\n' 'Deploy the database credentials and the native MariaDB, and wait for it:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifests.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -n "$NAMESPACE" -f manifests/secret.yaml -f manifests/mariadb.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the deployment rollout to complete.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl rollout status deployment/petclinic-db -n "$NAMESPACE" --timeout=300s
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 8. Protect PetClinic with SCONE'
printf '%s\n' ''
printf '%s\n' 'First, attest the CAS so the local SCONE CLI has the correct session encryption key. The kubectl path covers an in-cluster CAS; if it fails (typical when `${CAS_ENDPOINT}` points at an external CAS like `edge.scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Attest the CAS instance before sending encrypted policies.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \
    || scone cas attest ${CAS_ENDPOINT} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any \
    || echo "CAS attestation skipped: ${CAS_ENDPOINT} runs in simulation mode, so it cannot produce a DCAP quote"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then build the confidential image and generate the SCONE session from `manifests/scone.yaml`:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
scone-td-build apply -f manifests/scone.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Sconifies `java` and its dependencies into the confidential image and pushes it to `$DESTINATION_IMAGE_NAME`'
printf '%s\n' '- Generates a SCONE session that holds the datasource credentials from the Secret'
printf '%s\n' '- Produces `manifests/manifest.prod.sanitized.yaml`'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 9. Deploy the Confidential PetClinic'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -n "$NAMESPACE" -f manifests/manifest.prod.sanitized.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the deployment rollout to complete.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl rollout status deployment/petclinic -n "$NAMESPACE" --timeout=600s
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 10. Verify the Deployment'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# List the pods in the namespace.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl get pods -n "$NAMESPACE"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Check that the application answers over a temporary port-forward:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Forward the service port in the background.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl port-forward -n "$NAMESPACE" svc/petclinic 18080:80 >/dev/null 2>&1 &
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
PORT_FORWARD_PID=$!
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the port-forward even if the check below fails.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Probe the UI until it answers.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
retry-spinner --retries 20 --wait 3 -- curl -fsS -o /dev/null http://localhost:18080/
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
echo "PetClinic answered on http://localhost:18080/"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill "$PORT_FORWARD_PID" 2>/dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
trap - EXIT
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'To browse the UI yourself, keep a port-forward open in a separate terminal (this block is intentionally not part of the generated script):'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 11. Clean Up'
printf '%s\n' ''
printf '%s\n' 'Delete the demo resources (the namespace itself is kept, since it holds the pull secret):'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resources created by this demo.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -n "$NAMESPACE" --ignore-not-found -f manifests/manifest.prod.sanitized.yaml -f manifests/mariadb.yaml -f manifests/secret.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the pods to be deleted.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl wait --for=delete pod -l app=petclinic -n "$NAMESPACE" --timeout=300s || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Return to the previous working directory.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
popd
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Design Notes'
printf '%s\n' ''
printf '%s\n' 'A few choices are specific to running a modern JVM confidentially:'
printf '%s\n' ''
printf '%s\n' '- `reference-image: busybox`. The reference image is a skip-list: any binary present in it is left untouched by the sconify step. `java` is dynamically linked against glibc and dlopens the JRE `.so` libraries, so its whole dependency tree must be sconified into the enclave link map. Pointing the skip-list at the JRE base (or the target image itself) would drop those dependencies and the enclave would abort with `libpthread ... not found in the enclave link map`.'
printf '%s\n' '- JRE base pinned to glibc 2.39 (`eclipse-temurin:17-jre-noble`). SCONE 6.x ships glibc 2.39. The rolling `17-jre` tag now resolves to a much newer glibc, and that skew breaks the enclave link map for `java`'\''s direct dependencies. Keeping the base glibc aligned with SCONE avoids it.'
printf '%s\n' '- `ENCLAVE_HEAP=4G` and JVM memory caps. The enclave'\''s protected heap must hold the entire JVM footprint. The command bounds the JVM (`-Xmx`, `-XX:MaxMetaspaceSize`, `-XX:CompressedClassSpaceSize`, `-XX:ReservedCodeCacheSize`) so VM initialisation fits inside the heap.'
printf '%s\n' '- `SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MariaDBDialect`. This is an application-level fix (it is needed with or without SCONE): Hibernate 7.4'\''s dialect auto-detection issues a probe query that references a column MariaDB 11.4 does not have, so the dialect must be pinned explicitly.'
printf "%b" "$RESET"

