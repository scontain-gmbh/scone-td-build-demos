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

Runs a demo-style shell script generated from demos/hello-world/README.md.

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
export DEMO_DIR="$(cd "${script_dir}/../demos/hello-world" && pwd)"

printf "%b" "$LILAC"
printf '%s\n' '# SCONE: Hello World'
printf '%s\n' ''
printf '%s\n' '[![Hello World Example](../../docs/hello-world.gif)](../../docs/hello-world.mp4)'
printf '%s\n' ''
printf '%s\n' 'This example shows how to build a simple cloud-native `hello-world` application in Rust, run it natively in Kubernetes, and then deploy a confidential version with SCONE.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:'
printf '%s\n' ''
printf '%s\n' '- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)'
printf '%s\n' '- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Every file reference below goes through `$DEMO_DIR`, this demo'\''s directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# The generated scripts set DEMO_DIR to this demo's directory. When following
EOF
)"
pe "$(cat <<'EOF'
# this README by hand, run the commands from `demos/hello-world`.
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
rm -f "$DEMO_DIR/manifests/storage.json"
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
printf '%s\n' 'Load the full variable set with `tplenv`, which also defines the registry credentials used later to create the pull secret:'
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Kubernetes namespace if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -n ${NAMESPACE} -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate the job manifest with the selected image and pull-secret values:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/manifest.job.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.job.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 3. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t $NATIVE_IMAGE_NAME "$DEMO_DIR/app"
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $NATIVE_IMAGE_NAME
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using the registry credentials loaded in step 2.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the pull secret only when it does not already exist, so reruns with a
EOF
)"
pe "$(cat <<'EOF'
# precreated secret do not require registry credentials.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
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
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server="$REGISTRY" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Run the Native Hello-World Application'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job hello-world -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
EOF
)"
pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f "$DEMO_DIR/manifests/manifest.job.yaml" -n ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Poll for a terminal state instead of `kubectl wait`: this kubectl version only
EOF
)"
pe "$(cat <<'EOF'
# honors the last --for flag when given more than once, so it can't watch for
EOF
)"
pe "$(cat <<'EOF'
# both Complete and Failed in one call, and `wait -n` (used in an earlier
EOF
)"
pe "$(cat <<'EOF'
# version of this check) isn't portable to bash 3.2 or zsh. The Job is
EOF
)"
pe "$(cat <<'EOF'
# configured with backoffLimit: 4 and restartPolicy: OnFailure, so we wait for
EOF
)"
pe "$(cat <<'EOF'
# the Failed *condition* (set only once retries are exhausted), not
EOF
)"
pe "$(cat <<'EOF'
# .status.failed (a per-attempt retry counter that can tick up while the Job
EOF
)"
pe "$(cat <<'EOF'
# is still retrying and will go on to succeed).
EOF
)"
pe "$(cat <<'EOF'
deadline=$((SECONDS + 300))
EOF
)"
pe "$(cat <<'EOF'
terminal=""
EOF
)"
pe "$(cat <<'EOF'
while [[ $SECONDS -lt $deadline ]]; do
EOF
)"
pe "$(cat <<'EOF'
  complete=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'
  failed=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'
  if [[ "$complete" == "True" ]] || [[ "$failed" == "True" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    terminal=1
EOF
)"
pe "$(cat <<'EOF'
    break
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  sleep 2
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$terminal" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Timed out waiting for job/hello-world to complete or fail" >&2
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'
# Exit non-zero early if the job failed rather than completed.
EOF
)"
pe "$(cat <<'EOF'
kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q '^True$' && { echo "Job hello-world failed"; exit 1; } || true
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job hello-world -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Attest CAS before sending encrypted policies. The kubectl path covers in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.'
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
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 7. Build the Confidential Image and Manifest'
printf '%s\n' ''
printf '%s\n' 'Render the SCONE manifest, which contains everything needed to register the confidential image and transform the Kubernetes manifest in one step:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
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
printf '%s\n' 'This command registers the confidential image, creates the SCONE session, and produces `$DEMO_DIR/manifests/manifest.prod.sanitized.yaml` from `manifest.job.yaml`.'
printf '%s\n' ''
printf '%s\n' '## 8. Deploy the Confidential Manifest'
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
pe "$(cat <<'EOF'
# Poll for a terminal state instead of `kubectl wait`: this kubectl version only
EOF
)"
pe "$(cat <<'EOF'
# honors the last --for flag when given more than once, so it can't watch for
EOF
)"
pe "$(cat <<'EOF'
# both Complete and Failed in one call, and `wait -n` (used in an earlier
EOF
)"
pe "$(cat <<'EOF'
# version of this check) isn't portable to bash 3.2 or zsh. The Job is
EOF
)"
pe "$(cat <<'EOF'
# configured with backoffLimit: 4 and restartPolicy: OnFailure, so we wait for
EOF
)"
pe "$(cat <<'EOF'
# the Failed *condition* (set only once retries are exhausted), not
EOF
)"
pe "$(cat <<'EOF'
# .status.failed (a per-attempt retry counter that can tick up while the Job
EOF
)"
pe "$(cat <<'EOF'
# is still retrying and will go on to succeed).
EOF
)"
pe "$(cat <<'EOF'
deadline=$((SECONDS + 300))
EOF
)"
pe "$(cat <<'EOF'
terminal=""
EOF
)"
pe "$(cat <<'EOF'
while [[ $SECONDS -lt $deadline ]]; do
EOF
)"
pe "$(cat <<'EOF'
  complete=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'
  failed=$(kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'
  if [[ "$complete" == "True" ]] || [[ "$failed" == "True" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    terminal=1
EOF
)"
pe "$(cat <<'EOF'
    break
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  sleep 2
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$terminal" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Timed out waiting for job/hello-world to complete or fail" >&2
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'
# Exit non-zero early if the job failed rather than completed.
EOF
)"
pe "$(cat <<'EOF'
kubectl get job/hello-world -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q '^True$' && { echo "Job hello-world failed"; exit 1; } || true
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 9. Uninstall `hello-world`'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job hello-world -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Automation'
printf '%s\n' ''
printf '%s\n' 'You can run this workflow with:'
printf '%s\n' ''
printf '%s\n' './scripts/demos/hello-world.sh'
printf '%s\n' ''
printf '%s\n' 'It asks for user input unless you set:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"'
printf '%s\n' ''
printf '%s\n' 'This uses values from `demos/hello-world/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.'
printf '%s\n' ''
printf '%s\n' 'If you update commands in this document, run `./scripts/extract-all-demo-scripts.sh` to regenerate `./scripts/demos/hello-world.sh`.'
printf "%b" "$RESET"

