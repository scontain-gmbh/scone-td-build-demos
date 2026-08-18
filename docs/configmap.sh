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

Runs a demo-style shell script generated from demos/configmap/README.md.

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
# Directory of the README this script was generated from. The README
# code blocks use it for every file reference so the script works from
# any working directory.
export DEMO_DIR="$(cd "${script_dir}/../demos/configmap" && pwd)"

printf "%b" "$LILAC"
printf '%s\n' '# SCONE ConfigMap Example: Secure Configuration Data in Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a SCONE-enabled Rust application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.'
printf '%s\n' ''
printf '%s\n' '[![ConfigMap Example](../../docs/configmap.gif)](../../docs/configmap.mp4)'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Every file reference below goes through `$DEMO_DIR`, this demo'\''s directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# The generated scripts set DEMO_DIR to this demo's directory. When following
EOF
)"
pe "$(cat <<'EOF'
# this README by hand, run the commands from `demos/configmap`.
EOF
)"
pe "$(cat <<'EOF'
export DEMO_DIR="${DEMO_DIR:-$PWD}"
EOF
)"
pe "$(cat <<'EOF'
# Remove `storage.json` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm -f "$DEMO_DIR/manifests/storage.json" || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Seed Values.yaml from the template on first run only.
EOF
)"
pe "$(cat <<'EOF'
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
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
printf '%s\n' 'Load the full variable set from `environment-variables.md`, which also defines the registry credentials used later to create the pull secret:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist. The fallback echo keeps re-runs idempotent.'
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
printf '%s\n' '## 4. Build the Native Rust Image'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push ${NATIVE_IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Render the Manifests'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml" --indent
EOF
)"
pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Before applying, confirm that image values were substituted correctly.'
printf '%s\n' ''
printf '%s\n' '## 6. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'If you need a pull secret for native and confidential images, create it when missing:'
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
printf '%s\n' '## 7. Deploy the Native App (Optional)'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-1
EOF
)"
pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-2
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Clean up native app
EOF
)"
pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Your containers should print content from the mounted ConfigMap files.'
printf '%s\n' ''
printf '%s\n' '## 8. Prepare and Apply the SCONE Manifest'
printf '%s\n' ''
printf '%s\n' 'First, attest the CAS so the local SCONE CLI has the correct session encryption key. The kubectl path covers an in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Attest the CAS instance before sending encrypted policies.
EOF
)"
pe "$(cat <<'EOF'
kubectl scone cas attest --namespace "${SCONE_CAS_ADDR#*.}" "${SCONE_CAS_ADDR%%.*}" -C -G -S \
  || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
    --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Generates a SCONE session'
printf '%s\n' '- Attaches the session to your manifest'
printf '%s\n' '- Produces `$DEMO_DIR/manifests/manifest.prod.sanitized.yaml`'
printf '%s\n' ''
printf '%s\n' '## 9. Deploy the SCONE-Protected App'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 10. View Logs'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-1 --follow
EOF
)"
pe "$(cat <<'EOF'
# Retry the wrapped command until it succeeds or reaches the retry limit.
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/my-rust-app -n ${NAMESPACE} -c reader-2 --follow
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 11. Clean Up'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
EOF
)"

