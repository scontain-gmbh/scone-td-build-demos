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

Runs a demo-style shell script generated from demos/network-policy/README.md.

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
export DEMO_DIR="$(cd "${script_dir}/../demos/network-policy" && pwd)"

printf "%b" "$LILAC"
printf '%s\n' '# Network Policy'
printf '%s\n' ''
printf '%s\n' 'This guide explains how to build, deploy, and test the **Network Policy demo** with `scone-td-build`. You will build client and server images, generate SCONE-protected images, apply Kubernetes manifests, and verify the result.'
printf '%s\n' ''
printf '%s\n' '[![Network Policy Example](../docs/network-policy.gif)](../docs/network-policy.mp4)'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' 'Make sure you have:'
printf '%s\n' ''
printf '%s\n' '- Docker'
printf '%s\n' '- A Kubernetes cluster with `kubectl` configured'
printf '%s\n' '- `tplenv`'
printf '%s\n' '- `scone-td-build` built locally'
printf '%s\n' '- Access to a container registry where you can push images'
printf '%s\n' ''
printf '%s\n' '## 2. Build Images'
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
printf '%s\n' 'Every file reference below goes through `$DEMO_DIR`, this demo'\''s directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# The generated scripts set DEMO_DIR to this demo's directory. When following
EOF
)"
pe "$(cat <<'EOF'
# this README by hand, run the commands from `demos/network-policy`.
EOF
)"
pe "$(cat <<'EOF'
export DEMO_DIR="${DEMO_DIR:-$PWD}"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Remove `netshield.json` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm -f "$DEMO_DIR/netshield.json" || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Initialize environment variables from `environment-variables.md` using `tplenv`:'
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
printf '%s\n' 'Create the demo namespace if it does not already exist:'
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
printf '%s\n' 'Build and push native images:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t $SERVER_IMAGE "$DEMO_DIR/app/server/"
EOF
)"
pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t $CLIENT_IMAGE "$DEMO_DIR/app/client/"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $SERVER_IMAGE
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $CLIENT_IMAGE
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 3. Generate SCONE Images'
printf '%s\n' ''
printf '%s\n' 'Create SCONE config files from templates, then run `scone-td-build`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --output "$DEMO_DIR/manifests/manifest.yaml"
EOF
)"
pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --output "$DEMO_DIR/manifests/scone.yaml" --indent
EOF
)"
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
printf '%s\n' 'Push the generated SCONE images:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $SERVER_IMAGE-scone
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $CLIENT_IMAGE-scone
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Apply Kubernetes Manifests'
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
printf '%s\n' 'Wait until all pods are running before continuing.'
printf '%s\n' ''
printf '%s\n' '## 5. Test the Setup'
printf '%s\n' ''
printf '%s\n' 'Wait for pods and port-forward the server service:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=Ready pod -l app="server" -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=Ready pod -l app="client" -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# A ready pod does not always mean the port is immediately available.
EOF
)"
pe "$(cat <<'EOF'
# Wait briefly for the service to become reachable.
EOF
)"
pe "$(cat <<'EOF'
sleep 10
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Start a local port-forward to the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward svc/barad-dur 3000 -n ${NAMESPACE} & echo $! > /tmp/pf-3000.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Send requests:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Send a test request to the demo service endpoint.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
EOF
)"
pe "$(cat <<'EOF'
# Send a test request to the demo service endpoint.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Expected result: a random 7-character password, which confirms:'
printf '%s\n' ''
printf '%s\n' '- The application is running correctly'
printf '%s\n' '- SCONE-protected images are working'
printf '%s\n' '- Network Policy rules allow the intended traffic'
printf '%s\n' ''
printf '%s\n' '## 6. Uninstall the Demo'
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
pe "$(cat <<'EOF'
# Stop the previous background process if it is still running.
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-3000.pid) || true
EOF
)"
pe "$(cat <<'EOF'
# Remove `/tmp/pf-3000.pid` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-3000.pid
EOF
)"

