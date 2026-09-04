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

Runs a demo-style shell script generated from nfs-shared-volume/README.md.

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
printf '%s\n' '# SCONE: NFS-backed shared volume'
printf '%s\n' ''
printf '%s\n' 'This example shows `scone-td-build`'\''s automatic NFS sharing (issue #267): when a'
printf '%s\n' 'single volume is used by more than one pod, the tool re-shares it over NFS'
printf '%s\n' 'instead of mounting it directly into each pod.'
printf '%s\n' ''
printf '%s\n' 'The app (`app.py`) is a single image that runs in two roles, selected by `ROLE`:'
printf '%s\n' ''
printf '%s\n' '- **writer** appends a timestamped line to `/data/shared.log` every few seconds.'
printf '%s\n' '- **reader** reads `/data/shared.log` every few seconds and prints what it sees.'
printf '%s\n' ''
printf '%s\n' '`manifest.template.yaml` deploys both as separate Deployments, each mounting the'
printf '%s\n' 'same `shared-data` PVC at `/data`. Because that PVC is shared by two workloads,'
printf '%s\n' '`scone-td-build` automatically:'
printf '%s\n' ''
printf '%s\n' '1. generates a native NFS server that mounts the PVC and re-exports it over NFSv4, and'
printf '%s\n' '2. rewrites each consumer'\''s `data` volume to mount that NFS export instead of the PVC directly.'
printf '%s\n' ''
printf '%s\n' 'The result: the reader sees exactly what the writer wrote, through the shared NFS export.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support and the SCONE stack (operator + LAS + CAS)'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`) and the `kubectl scone` plugin'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- A `scone-td-build` binary with NFS shared-volume support'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools.'
printf '%s\n' ''
printf '%s\n' '### Node prerequisites (specific to this demo)'
printf '%s\n' ''
printf '%s\n' 'Unlike the other demos, the NFS re-sharing needs two things on every node that'
printf '%s\n' 'runs a consumer or the NFS server: the `mount.nfs` helper (`nfs-common`) and host'
printf '%s\n' 'resolution of the NFS service DNS name. These are node-level, not something the'
printf '%s\n' 'manifest or `Values.yaml` can set, so they are a one-time cluster prerequisite.'
printf '%s\n' ''
printf '%s\n' 'Apply them once per cluster as described in [`node-prep/README.md`](node-prep/README.md).'
printf '%s\n' 'On a cluster that already has `nfs-common` and cluster DNS wired to the nodes you'
printf '%s\n' 'can skip this.'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'We assume you start in `scone-td-build-demos`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Enter `nfs-shared-volume` and remember the previous directory.
EOF
)"
pe "$(cat <<'EOF'
pushd nfs-shared-volume
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:'
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
printf '%s\n' '## 3. Render the Manifests'
printf '%s\n' ''
printf '%s\n' 'Render the native manifest and the scone-td-build spec with the selected values:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the Kubernetes manifest (two Deployments sharing one PVC).
EOF
)"
pe "$(cat <<'EOF'
tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
EOF
)"
pe "$(cat <<'EOF'
# Render the scone-td-build Register + Apply spec.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the writer/reader image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t "$IMAGE_NAME" .
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push "$IMAGE_NAME"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
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
  # Load registry credentials.
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
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
printf '%s\n' '## 6. Register the Image and Transform the Manifest'
printf '%s\n' ''
printf '%s\n' '`scone-td-build apply` runs the Register plus Apply flow from a single spec: it'
printf '%s\n' 'registers/sconifies the image, detects the shared PVC, wires in the NFS server,'
printf '%s\n' 'and writes the transformed manifest and the CAS policies.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Register the image and transform the manifest in one step.
EOF
)"
pe "$(cat <<'EOF'
scone-td-build apply -f manifests/scone.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This demo uses a **signed** CAS policy (`encrypted-cas-policy: false` in'
printf '%s\n' '`scone.template.yaml`), so this step does not attest or encrypt against the CAS'
printf '%s\n' 'and needs no SGX on the machine running it. See "How the security posture is'
printf '%s\n' 'set" below.'
printf '%s\n' ''
printf '%s\n' '## 7. Deploy the Confidential Manifest'
printf '%s\n' ''
printf '%s\n' 'The transformed manifest (`manifests/manifest.sanitized.yaml`) contains the'
printf '%s\n' 'sconified writer/reader Deployments, the generated NFS server Deployment and'
printf '%s\n' 'Service, and the signed CAS policies.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the transformed manifest and the CAS policies.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifests/manifest.sanitized.yaml -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the workloads to become available.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deploy/nfs-shared-data -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deploy/file-writer -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deploy/file-reader -n ${NAMESPACE} --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Observe the Shared Volume'
printf '%s\n' ''
printf '%s\n' 'The reader'\''s line count should climb and its "last" line should match what the'
printf '%s\n' 'writer just wrote, confirming both pods share the same file over the generated'
printf '%s\n' 'NFS export.'
printf '%s\n' ''
printf '%s\n' 'The first write does not happen immediately. A freshly started NFSv4 server'
printf '%s\n' 'holds a **grace period** of about 90 seconds, during which it refuses the'
printf '%s\n' 'state-establishing opens that a write needs, so the writer'\''s first `open()`'
printf '%s\n' 'blocks until that period ends. Reads are not affected, which is why the reader'
printf '%s\n' 'reports `shared file not created by the writer yet` in the meantime. Wait for'
printf '%s\n' 'the reader to actually see the file instead of sleeping for a fixed time:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Wait until the reader sees the shared file. The generous budget covers the
EOF
)"
pe "$(cat <<'EOF'
# NFSv4 grace period (~90s) on the freshly started server.
EOF
)"
pe "$(cat <<'EOF'
deadline=$(( $(date +%s) + 240 ))
EOF
)"
pe "$(cat <<'EOF'
until kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=20 2>/dev/null | grep -q 'line(s) so far'; do
EOF
)"
pe "$(cat <<'EOF'
  if [ "$(date +%s)" -ge "${deadline}" ]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "The reader never saw the shared file through the NFS export" >&2
EOF
)"
pe "$(cat <<'EOF'
    kubectl logs -n ${NAMESPACE} deploy/file-writer --tail=20 >&2 || true
EOF
)"
pe "$(cat <<'EOF'
    kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=20 >&2 || true
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
  sleep 5
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'
# The writer appends timestamped lines.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} deploy/file-writer --tail=5
EOF
)"
pe "$(cat <<'EOF'
# The reader sees the same lines through the NFS export.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=5
EOF
)"
pe "$(cat <<'EOF'
# Prove it is one shared file and not two local ones: the reader's most recent
EOF
)"
pe "$(cat <<'EOF'
# line must be a line the writer actually wrote.
EOF
)"
pe "$(cat <<'EOF'
last_seen=$(kubectl logs -n ${NAMESPACE} deploy/file-reader --tail=1 | sed -n 's/.*last: //p')
EOF
)"
pe "$(cat <<'EOF'
if [ -z "${last_seen}" ]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Could not read the reader's most recent line" >&2
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
if ! kubectl logs -n ${NAMESPACE} deploy/file-writer --tail=50 | grep -qF "${last_seen}"; then
EOF
)"
pe "$(cat <<'EOF'
  echo "The reader's most recent line does not match anything the writer wrote" >&2
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
echo "The reader sees exactly what the writer wrote, through the NFS export"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 9. Uninstall'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the workloads, the shared PVC, and the CAS policies.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f manifests/manifest.sanitized.yaml -n ${NAMESPACE} --ignore-not-found
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

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Automation'
printf '%s\n' ''
printf '%s\n' 'You can run this workflow with:'
printf '%s\n' ''
printf '%s\n' './scripts/nfs-shared-volume.sh'
printf '%s\n' ''
printf '%s\n' 'It asks for user input unless you set:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"'
printf '%s\n' ''
printf '%s\n' 'This uses values from `nfs-shared-volume/Values.yaml` and skips interactive prompts.'
printf '%s\n' ''
printf '%s\n' 'If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/nfs-shared-volume.sh`.'
printf '%s\n' ''
printf '%s\n' '## How the security posture is set'
printf '%s\n' ''
printf '%s\n' '`scone-td-build` talks to the CAS through the `scone` CLI, which runs as a SCONE'
printf '%s\n' 'enclave. Two independent knobs decide how much SGX the setup step needs:'
printf '%s\n' ''
printf '%s\n' '- **Policy protection** (`encrypted-cas-policy` in the Apply block). `false`'
printf '%s\n' '  (this demo) produces a *signed* policy: no CAS attestation, no encryption, only'
printf '%s\n' '  a local `scone session sign`, which does not require SGX2 on the setup host.'
printf '%s\n' '  `true` produces an *encrypted* policy: it attests the CAS and encrypts the'
printf '%s\n' '  session to the CAS'\''s attested key inside the enclave, so the setup host needs'
printf '%s\n' '  SGX. Use `true` when the setup runs on an untrusted host and the policy carries'
printf '%s\n' '  secrets that must never appear in clear.'
printf '%s\n' '- **Enclave mode** (`SCONE_PRODUCTION`, `SCONE_MODE`). Controls debug/simulation'
printf '%s\n' '  versus production enclaves. It is orthogonal to the policy choice above.'
printf '%s\n' ''
printf '%s\n' 'Either way, only the cluster nodes that run the transformed manifest need SGX;'
printf '%s\n' 'the workloads attest to the CAS at runtime there.'
printf "%b" "$RESET"

