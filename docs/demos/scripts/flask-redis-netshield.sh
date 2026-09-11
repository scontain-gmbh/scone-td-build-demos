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

Runs a demo-style shell script generated from flask-redis-netshield/README.md.

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
printf '%s\n' '# Flask Redis Netshield'
printf '%s\n' ''
printf '%s\n' 'A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.'
printf '%s\n' 'This guide walks through deploying the **native** version first, running integration tests, and then building and deploying the **confidential** (SCONE) version before testing it again.'
printf '%s\n' ''
printf '%s\n' '[![Flask Redis Netshield Example](../docs/flask-redis-netshield.gif)](../docs/flask-redis-netshield.mp4)'
printf '%s\n' ''
printf '%s\n' '## Project Structure'
printf '%s\n' ''
printf '%s\n' 'flask-redis-netshield/'
printf '%s\n' '├── app.py                       # Flask application'
printf '%s\n' '├── Dockerfile                   # Flask image build'
printf '%s\n' '├── requirements.txt             # Python dependencies'
printf '%s\n' '├── scone.template.yaml          # SCONE confidential build template'
printf '%s\n' '├── environment-variables.md     # tplenv variable definitions'
printf '%s\n' '├── registry.credentials.md      # tplenv registry credential definitions'
printf '%s\n' '├── k8s/'
printf '%s\n' '│   └── manifest.template.yaml   # Redis + Flask API deployment template'
printf '%s\n' '└── README.md'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Prerequisites'
printf '%s\n' ''
printf '%s\n' '- `kubectl` configured for your cluster'
printf '%s\n' '- `docker` with access to a registry your cluster can pull from'
printf '%s\n' '- `openssl` and `tplenv` available in your shell'
printf '%s\n' '- `scone-td-build` binary'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 1 — Native Deployment'
printf '%s\n' ''
printf '%s\n' '### Step 1. Generate TLS certificates'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Change into `flask-redis-netshield`.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
cd flask-redis-netshield
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create `certs` if it does not already exist.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
mkdir -p certs
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# CA
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the certificate authority private key.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl genrsa -out certs/redis-ca.key 4096
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a self-signed certificate.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Redis server cert
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the Redis server private key.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl genrsa -out certs/redis.key 2048
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a certificate signing request.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Sign the certificate with the certificate authority.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Flask server cert
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the Flask server private key.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl genrsa -out certs/flask.key 2048
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a certificate signing request.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Sign the certificate with the certificate authority.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Client cert (used by Flask to connect to Redis)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the client private key.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl genrsa -out certs/client.key 2048
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a certificate signing request.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Sign the certificate with the certificate authority.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/client.crt -days 365 -sha256
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '| File | Used by | Purpose |'
printf '%s\n' '|---|---|---|'
printf '%s\n' '| `redis-ca.crt` | Both | CA that signed all certs |'
printf '%s\n' '| `redis.crt` / `redis.key` | Redis | Redis server cert/key |'
printf '%s\n' '| `flask.crt` / `flask.key` | Flask | Flask HTTPS server cert/key |'
printf '%s\n' '| `client.crt` / `client.key` | Flask | mTLS client cert for Redis |'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 2. Collect environment variables and build the Docker image'
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Export the required environment variable for the next steps.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
export SIGNER="$(scone self show-session-signing-key)"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then let `tplenv` query all environment variables used by this example:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Load environment variables from the tplenv definition file.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then build and push the native Docker image:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Build the container image.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
docker build -t ${IMAGE_NAME} .
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
printf '%s\n' '### Step 3. Create the namespace'
printf '%s\n' ''
printf '%s\n' 'We try to ensure the namespace exists. This may fail when running in a container that is already in the target namespace, so we ignore that failure.'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create the Kubernetes namespace if it does not already exist.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -n ${NAMESPACE} -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 4. Generate and inspect secret manifests'
printf '%s\n' ''
printf '%s\n' 'Generate the secret YAML files locally so you can inspect them before applying:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the Kubernetes secret manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl create -n ${NAMESPACE} secret generic redis-tls \
  --namespace ${NAMESPACE} \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the Kubernetes secret manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl create -n ${NAMESPACE} secret generic flask-tls \
  --namespace ${NAMESPACE} \
  --from-file=flask.crt=certs/flask.crt \
  --from-file=flask.key=certs/flask.key \
  --from-file=client.crt=certs/client.crt \
  --from-file=client.key=certs/client.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Review the files in `k8s/`, then apply them:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -n ${NAMESPACE} -f k8s/secret-redis-tls.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -n ${NAMESPACE} -f k8s/secret-flask-tls.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 5. Add Docker Registry Secret to Kubernetes'
printf '%s\n' ''
printf '%s\n' 'A pull secret is needed to pull both the native and confidential container images. Use `tplenv` to supply the registry credentials — it will prompt for any values not yet present in `Values.yaml`:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` — the registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` — your registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` — your registry pull token (see [how to create a token](https://sconedocs.github.io/registry/))'
printf '%s\n' ''
printf '%s\n' 'We create the pull secret in the namespace if it does not yet exist:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Check whether the pull secret already exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if kubectl get -n ${NAMESPACE} secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
else
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Load environment variables from the tplenv definition file.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} )
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Create the Docker registry pull secret.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  kubectl create -n ${NAMESPACE} secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 6. Generate the manifest from the template'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render the template with the selected values.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Review `k8s/manifest.yaml`, then apply it:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -n ${NAMESPACE} -f k8s/manifest.yaml --namespace ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 7. Verify the native deployment'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Watch all resources come up
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# List the demo's workloads. `get all` also lists provider resources the toolbox may not read.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl get deployments,replicasets,pods,services -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for Redis
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the deployment rollout to complete.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl rollout status deployment/redis -n ${NAMESPACE}  --watch=true  --timeout=240s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for Flask API
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the deployment rollout to complete.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --watch=true  --timeout=240s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Check logs
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Show logs from the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl logs -n ${NAMESPACE} deployment/flask-api --tail=50
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Show logs from the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl logs -n ${NAMESPACE} deployment/redis --tail=20
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 8. Test the native API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the Flask API pod:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the previous background process if it is still running.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Capture the name of a ready pod for port-forwarding.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | select(.metadata.deletionTimestamp == null)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | select(.status.phase=="Running")
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | .metadata.name' | head -n1)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Start a local port-forward to the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then send requests to `http://localhost:14996`. Note that we are only using `http` (and not yet `https`):'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# List all stored keys
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Request the list of stored keys from the service.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/keys
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a client record
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a test client record through the API.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -X POST http://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Retrieve a client
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Fetch the stored client record from the API.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/client/abc123
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Get credit score
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Request the credit score for the test client.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/score/abc123
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Memory dump (debug)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Request the debug memory dump from the API.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/memory
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 9. Tear down the native deployment'
printf '%s\n' ''
printf '%s\n' 'Remove the native workloads and secrets before switching to the confidential version:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -n ${NAMESPACE} -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 2 — Confidential Deployment (SCONE)'
printf '%s\n' ''
printf '%s\n' '### Step 10. Build the confidential (SCONE) images'
printf '%s\n' ''
printf '%s\n' 'When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. By default, `scone-td-build` assumes that this key is stored in the file `identity.pem`. We can generate this file as follows:'
printf '%s\n' ''
printf '%s\n' '- we first check if the file exists, and'
printf '%s\n' '- if it does not exist, we create it with `openssl`'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Check whether the signing key needs to be generated.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if [ ! -f identity.pem ]; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "Generating identity.pem ..."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Generate the signing key for confidential binaries.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  openssl genrsa -3 -out identity.pem 3072
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
else
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  # Print a status message.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  echo "identity.pem already exists."
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate the SCONE config from its template, then run `scone-td-build` to produce hardened confidential images for both Redis and Flask and push them to the registry:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Render the template with the selected values.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove `flask-redis-demo.json` if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm flask-redis-demo.json || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
scone-td-build apply -f scone.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Use the registry-backed Redis SCONE image that the Register step pushed.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
if grep -q 'image: redis:7-bookworm-scone' manifest.prod.sanitized.yaml; then
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  sed -i.bak "s|image: redis:7-bookworm-scone|image: ${IMAGE_NAME}-redis-scone|g" manifest.prod.sanitized.yaml
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
  rm -f manifest.prod.sanitized.yaml.bak
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
fi
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 11. Deploy the confidential version'
printf '%s\n' ''
printf '%s\n' 'Apply the production sanitized manifest that references the SCONE confidential images:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Apply the Kubernetes manifest.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl apply -n ${NAMESPACE} -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 12. Verify the confidential deployment'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Watch all resources come up
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# List the demo's workloads. `get all` also lists provider resources the toolbox may not read.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl get deployments,replicasets,pods,services -n ${NAMESPACE}
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for Redis
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the deployment rollout to complete.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=300s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for Flask API
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Wait for the deployment rollout to complete.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=300s
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Check logs
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Show logs from the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl logs -n ${NAMESPACE} deployment/flask-api --tail=50
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Show logs from the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl logs -n ${NAMESPACE} deployment/redis --tail=20
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 13. Test the confidential API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the confidential Flask API pod:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the previous background process if it is still running.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Capture the name of a ready pod for port-forwarding.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | select(.metadata.deletionTimestamp == null)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | select(.status.phase=="Running")
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
    | .metadata.name' | head -n1)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Start a local port-forward to the Kubernetes workload.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# List all stored keys
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Request the list of stored keys from the service.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/keys
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a client record
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Create a test client record through the API.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -X POST http://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Retrieve a client
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Fetch the stored client record from the API.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/client/abc123
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Get credit score
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Request the credit score for the test client.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/score/abc123
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Memory dump (debug)
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Request the debug memory dump from the API.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/memory
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Cleanup'
printf '%s\n' ''
printf '%s\n' 'Remove all deployed resources when you are finished:'
printf '%s\n' ''
printf "%b" "$RESET"

IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the port-forward
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Stop the previous background process if it is still running.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kill $(cat /tmp/pf-14996.pid) 2> /dev/null || true
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Remove `/tmp/pf-14996.pid` if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
rm /tmp/pf-14996.pid
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true

EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete confidential manifest resources
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
# Delete the Kubernetes resource if it exists.
EOF
pe "${PE_CMD%$'\n'}"
IFS= read -r -d '' PE_CMD <<'EOF' || true
kubectl delete -n ${NAMESPACE} -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE} --ignore-not-found
EOF
pe "${PE_CMD%$'\n'}"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## API Endpoints'
printf '%s\n' ''
printf '%s\n' 'All endpoints are exposed on port `4996` (mapped to `443` in Kubernetes).'
printf '%s\n' ''
printf '%s\n' '| Method | Path | Description |'
printf '%s\n' '|--------|------|-------------|'
printf '%s\n' '| `POST` | `/client/<client_id>` | Create a new client record |'
printf '%s\n' '| `GET` | `/client/<client_id>` | Retrieve a client by ID |'
printf '%s\n' '| `GET` | `/score/<client_id>` | Get the credit score for a client |'
printf '%s\n' '| `GET` | `/keys` | List all stored client records |'
printf '%s\n' '| `GET` | `/memory` | Dump process memory (debug only) |'
printf "%b" "$RESET"

