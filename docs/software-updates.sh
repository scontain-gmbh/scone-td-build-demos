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

Runs a demo-style shell script generated from software-updates/README.md.

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
printf '%s\n' '# Software Updates for Confidential Python Applications'
printf '%s\n' ''
printf '%s\n' 'This example demonstrates how to perform a **software update** of a confidential Python application using SCONE and `scone-td-build`. Two versions of the application are built and deployed:'
printf '%s\n' ''
printf '%s\n' '- **Version 1** — the initial confidential deployment'
printf '%s\n' '- **Version 2** — the updated version, deployed via a Kubernetes rolling update'
printf '%s\n' ''
printf '%s\n' 'The demo shows that secrets (such as `API_PASSWORD`) are **preserved across the update**, since they live in a Kubernetes Secret that is not touched during the application upgrade.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Project Structure'
printf '%s\n' ''
printf '%s\n' 'software-updates/'
printf '%s\n' '├── print_env1.py                  # Version 1 of the Python application'
printf '%s\n' '├── print_env2.py                  # Version 2 of the Python application'
printf '%s\n' '├── Dockerfile                     # Builds either version via --build-arg VERSION=1|2'
printf '%s\n' '├── requirements.txt               # No external dependencies (stdlib only)'
printf '%s\n' '├── scone.v1.template.yaml         # SCONE Register + Apply template for Version 1'
printf '%s\n' '├── scone.v2.template.yaml         # SCONE Register + Apply template for Version 2'
printf '%s\n' '├── environment-variables.md       # tplenv variable definitions'
printf '%s\n' '├── registry.credentials.md        # tplenv registry credential definitions'
printf '%s\n' '├── k8s/'
printf '%s\n' '│   ├── manifest.v1.template.yaml  # Kubernetes Deployment template for Version 1'
printf '%s\n' '│   └── manifest.v2.template.yaml  # Kubernetes Deployment template for Version 2'
printf '%s\n' '└── README.md'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- `docker` with push access to a registry your cluster can pull from'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 1. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Assume you start in `scone-td-build-demos` and switch into this demo directory:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Enter `software-updates` and remember the previous directory.
EOF
)"
pe "$(cat <<'EOF'
pushd software-updates
EOF
)"
pe "$(cat <<'EOF'
# Remove generated state files from any previous run.
EOF
)"
pe "$(cat <<'EOF'
rm -f software-updates-demo.json scone.v1.yaml scone.v2.yaml manifest.prod.sanitized.yaml manifest.prod.session.yaml || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Export the required environment variable for the next steps.
EOF
)"
pe "$(cat <<'EOF'
export SIGNER="$(scone self show-session-signing-key)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 2. Build and Push the Native Docker Images'
printf '%s\n' ''
printf '%s\n' 'The Dockerfile accepts a `VERSION` build argument to choose which Python script to embed. Build both versions:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the Version 1 container image.
EOF
)"
pe "$(cat <<'EOF'
docker build --build-arg VERSION=1 -t ${IMAGE_NAME_V1} .
EOF
)"
pe "$(cat <<'EOF'
# Push the Version 1 container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push ${IMAGE_NAME_V1}
EOF
)"
pe "$(cat <<'EOF'
# Build the Version 2 container image.
EOF
)"
pe "$(cat <<'EOF'
docker build --build-arg VERSION=2 -t ${IMAGE_NAME_V2} .
EOF
)"
pe "$(cat <<'EOF'
# Push the Version 2 container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push ${IMAGE_NAME_V2}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 3. Create the Kubernetes Namespace'
printf '%s\n' ''
printf '%s\n' 'We try to ensure the namespace exists. This may fail when running in a container already in the target namespace, so we ignore that failure.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Kubernetes namespace if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 4. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'A pull secret is needed to pull both the native and confidential container images.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` — the registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` — your registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` — your registry pull token (see [how to create a token](https://sconedocs.github.io/registry/))'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  # Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
EOF
)"
pe "$(cat <<'EOF'
  # Create the Docker registry pull secret.
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 5. Create the API Credentials Secret'
printf '%s\n' ''
printf '%s\n' 'The `API_USER` and `API_PASSWORD` are injected into the application from a Kubernetes Secret. The secret is created once and **persists across software updates**:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate a random API password.
EOF
)"
pe "$(cat <<'EOF'
API_PASSWORD=$(openssl rand -hex 16)
EOF
)"
pe "$(cat <<'EOF'
# Create the Kubernetes secret with the API credentials.
EOF
)"
pe "$(cat <<'EOF'
kubectl create secret generic api-credentials \
  --namespace ${NAMESPACE} \
  --from-literal=api-user=myself \
  --from-literal=api-password="${API_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
EOF
)"
pe "$(cat <<'EOF'
# Print a status message.
EOF
)"
pe "$(cat <<'EOF'
echo "API credentials secret created. Password checksum: $(echo -n "${API_PASSWORD}" | md5sum | cut -d' ' -f1)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Note the printed checksum. After the software update (Part 2 below), the application should print the **same checksum**, confirming the secret was preserved.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 6. Render the Manifests'
printf '%s\n' ''
printf '%s\n' 'Render the Kubernetes deployment manifest and SCONE configuration for Version 1:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the Version 1 deployment manifest.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file k8s/manifest.v1.template.yaml --create-values-file --output k8s/manifest.v1.yaml --indent
EOF
)"
pe "$(cat <<'EOF'
# Render the Version 1 SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file scone.v1.template.yaml --create-values-file --output scone.v1.yaml --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 1 — Deploy Version 1'
printf '%s\n' ''
printf '%s\n' '### Step 7. Generate the signing key'
printf '%s\n' ''
printf '%s\n' 'When protecting binaries for confidential execution, `scone-td-build` signs them with a key stored in `identity.pem`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the signing key needs to be generated.
EOF
)"
pe "$(cat <<'EOF'
if [ ! -f identity.pem ]; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Generating identity.pem ..."
EOF
)"
pe "$(cat <<'EOF'
  # Generate the signing key for confidential binaries.
EOF
)"
pe "$(cat <<'EOF'
  openssl genrsa -3 -out identity.pem 3072
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "identity.pem already exists."
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Step 8. Build the confidential image and session for Version 1'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Remove any existing state file.
EOF
)"
pe "$(cat <<'EOF'
rm -f software-updates-demo.json || true
EOF
)"
pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
scone-td-build from -y scone.v1.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Registers and pushes the Version 1 confidential image (`${DESTINATION_IMAGE_NAME_V1}`)'
printf '%s\n' '- Creates a CAS session'
printf '%s\n' '- Produces `manifest.prod.sanitized.yaml` referencing the confidential image'
printf '%s\n' ''
printf '%s\n' '### Step 9. Deploy Version 1'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Step 10. Verify the Version 1 deployment'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/python-hello-user -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} -l app=python-hello-user --tail=20
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'You should see output such as:'
printf '%s\n' ''
printf '%s\n' 'Version 1: Hello, '\''myself'\'' - thanks for passing along the API_PASSWORD'
printf '%s\n' 'The checksum of the original API_PASSWORD is '\''<checksum>'\'''
printf '%s\n' 'Version 1: Hello, user '\''myself'\''!'
printf '%s\n' 'The checksum of the current password is '\''<checksum>'\'''
printf '%s\n' 'Running Version 1. Update by re-applying the v2 confidential manifest.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 2 — Software Update to Version 2'
printf '%s\n' ''
printf '%s\n' 'The API credentials Secret is **not modified** during this update. The same `api-credentials` Kubernetes Secret is mounted into both v1 and v2 pods.'
printf '%s\n' ''
printf '%s\n' '### Step 11. Render the manifests for Version 2'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the Version 2 deployment manifest.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file k8s/manifest.v2.template.yaml --create-values-file --output k8s/manifest.v2.yaml --indent
EOF
)"
pe "$(cat <<'EOF'
# Render the Version 2 SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file scone.v2.template.yaml --create-values-file --output scone.v2.yaml --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Step 12. Build the confidential image and update the session for Version 2'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
scone-td-build from -y scone.v2.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Registers and pushes the Version 2 confidential image (`${DESTINATION_IMAGE_NAME_V2}`)'
printf '%s\n' '- Updates the existing CAS session (same session name as Version 1)'
printf '%s\n' '- Produces `manifest.prod.sanitized.yaml` referencing the Version 2 confidential image'
printf '%s\n' ''
printf '%s\n' '### Step 13. Apply the update'
printf '%s\n' ''
printf '%s\n' 'Applying the new manifest triggers a Kubernetes **rolling update** — the v1 pods are replaced by v2 pods without downtime:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the updated Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the rolling update to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/python-hello-user -n ${NAMESPACE} --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Step 14. Verify the Version 2 deployment'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} -l app=python-hello-user --tail=20
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'You should see output such as:'
printf '%s\n' ''
printf '%s\n' 'Version 2 (updated): Hello, '\''myself'\'' - software update successful!'
printf '%s\n' 'The checksum of the original API_PASSWORD is '\''<checksum>'\'''
printf '%s\n' 'Version 2: Hello, user '\''myself'\''!'
printf '%s\n' 'The checksum of the current password is '\''<checksum>'\'''
printf '%s\n' 'Running Version 2.'
printf '%s\n' ''
printf '%s\n' 'The **checksum must match** the one printed by Version 1 and the one printed in Step 5, confirming that `API_PASSWORD` was preserved across the software update.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Cleanup'
printf '%s\n' ''
printf '%s\n' 'Remove all deployed resources when you are finished:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes deployment.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete deployment python-hello-user --namespace ${NAMESPACE} --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
# Wait for the pods to be terminated.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=python-hello-user --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# Delete the API credentials secret.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete secret api-credentials --namespace ${NAMESPACE} --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
# Return to the previous working directory.
EOF
)"
pe "$(cat <<'EOF'
popd
EOF
)"

