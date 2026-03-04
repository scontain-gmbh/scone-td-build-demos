#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# flask-redis'
printf '%s\n' ''
printf '%s\n' 'A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.'
printf '%s\n' ''
printf '%s\n' '## Project Structure'
printf '%s\n' ''
printf '%s\n' 'flask-redis/'
printf '%s\n' '├── app.py                  # Flask application'
printf '%s\n' '├── Dockerfile              # Flask image build'
printf '%s\n' '├── requirements.txt        # Python dependencies'
printf '%s\n' '├── deploy.sh               # Automated deploy + test script'
printf '%s\n' '├── k8s/'
printf '%s\n' '│   └── manifest.template.yaml  # Redis + Flask API deployment template'
printf '%s\n' '└── README.md'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Deploy'
printf '%s\n' ''
printf '%s\n' 'There are two ways to deploy: run the **automated script** (recommended) or follow the **manual steps** below.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Option A — Automated script'
printf '%s\n' ''
printf '%s\n' 'The `deploy.sh` script handles everything end-to-end: TLS cert generation, Docker build and push, Kubernetes secret and manifest generation, deployment, and integration tests via port-forward. It also cleans up all deployed resources when it finishes (or if something goes wrong).'
printf '%s\n' ''
printf '%s\n' '#### Usage'
printf '%s\n' ''
printf '%s\n' 'Usage: ./deploy.sh --image <IMAGE> [--certs <CERTS_DIR>] [--k8s <K8S_DIR>] [--namespace <NAMESPACE>]'
printf '%s\n' ''
printf '%s\n' 'Flags:'
printf '%s\n' '  -i, --image        Image name (required), e.g. myregistry/flask-redis-api:latest'
printf '%s\n' '  --certs            Path to certs directory (default: <script-dir>/certs)'
printf '%s\n' '  --k8s              Path to k8s manifests directory (default: <script-dir>/k8s)'
printf '%s\n' '  -n, --namespace    Kubernetes namespace (default: flask-redis)'
printf '%s\n' ''
printf '%s\n' '#### Example'
printf '%s\n' ''
printf '%s\n' 'chmod +x deploy.sh'
printf '%s\n' './deploy.sh --image myregistry/flask-redis-api:latest'
printf '%s\n' ''
printf '%s\n' 'With custom paths:'
printf '%s\n' ''
printf '%s\n' './deploy.sh \'
printf '%s\n' '  --image myregistry/flask-redis-api:latest \'
printf '%s\n' '  --certs ./my-certs \'
printf '%s\n' '  --k8s ./k8s \'
printf '%s\n' '  --namespace flask-redis'
printf '%s\n' ''
printf '%s\n' 'The script will pause after generating the secret and manifest YAML files in `--k8s` so you can inspect them before anything is applied to the cluster. After the tests finish, all deployed resources are automatically removed.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Option B — Manual steps'
printf '%s\n' ''
printf '%s\n' '#### Prerequisites'
printf '%s\n' ''
printf '%s\n' '- `kubectl` configured for your cluster'
printf '%s\n' '- `docker` with access to a registry your cluster can pull from'
printf '%s\n' '- `openssl` and `tplenv` available in your shell'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 1. Generate TLS certificates'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'mkdir -p certs'
printf '%s\n' ''
printf '%s\n' '# CA'
printf '%s\n' 'openssl genrsa -out certs/redis-ca.key 4096'
printf '%s\n' 'openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \'
printf '%s\n' '  -out certs/redis-ca.crt -subj "/CN=redis-ca"'
printf '%s\n' ''
printf '%s\n' '# Redis server cert'
printf '%s\n' 'openssl genrsa -out certs/redis.key 2048'
printf '%s\n' 'openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"'
printf '%s\n' 'openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \'
printf '%s\n' '  -CAcreateserial -out certs/redis.crt -days 365 -sha256'
printf '%s\n' ''
printf '%s\n' '# Flask server cert'
printf '%s\n' 'openssl genrsa -out certs/flask.key 2048'
printf '%s\n' 'openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"'
printf '%s\n' 'openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \'
printf '%s\n' '  -CAcreateserial -out certs/flask.crt -days 365 -sha256'
printf '%s\n' ''
printf '%s\n' '# Client cert (used by Flask to connect to Redis)'
printf '%s\n' 'openssl genrsa -out certs/client.key 2048'
printf '%s\n' 'openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"'
printf '%s\n' 'openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \'
printf '%s\n' '  -CAcreateserial -out certs/client.crt -days 365 -sha256'
printf "${RESET}"

mkdir -p certs

# CA
openssl genrsa -out certs/redis-ca.key 4096
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca"

# Redis server cert
openssl genrsa -out certs/redis.key 2048
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"
openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256

# Flask server cert
openssl genrsa -out certs/flask.key 2048
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"
openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256

# Client cert (used by Flask to connect to Redis)
openssl genrsa -out certs/client.key 2048
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"
openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/client.crt -days 365 -sha256

printf "${VIOLET}"
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
printf '%s\n' '#### 2. Build and push the Docker image'
printf '%s\n' ''
printf '%s\n' 'First, let `tplenv` query all environment variables used by this example:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then build and push the Docker image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'docker build -t ${IMAGE_NAME} .'
printf '%s\n' 'docker push ${IMAGE_NAME}'
printf "${RESET}"

docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 3. Create the namespace'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create namespace ${NAMESPACE}'
printf "${RESET}"

kubectl create namespace ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 4. Generate and inspect secret manifests'
printf '%s\n' ''
printf '%s\n' 'Generate the secret YAML files locally so you can inspect them before applying:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create secret generic redis-tls \'
printf '%s\n' '  --namespace ${NAMESPACE} \'
printf '%s\n' '  --from-file=redis.crt=certs/redis.crt \'
printf '%s\n' '  --from-file=redis.key=certs/redis.key \'
printf '%s\n' '  --from-file=redis-ca.crt=certs/redis-ca.crt \'
printf '%s\n' '  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml'
printf '%s\n' ''
printf '%s\n' 'kubectl create secret generic flask-tls \'
printf '%s\n' '  --namespace ${NAMESPACE} \'
printf '%s\n' '  --from-file=flask.crt=certs/flask.crt \'
printf '%s\n' '  --from-file=flask.key=certs/flask.key \'
printf '%s\n' '  --from-file=client.crt=certs/client.crt \'
printf '%s\n' '  --from-file=client.key=certs/client.key \'
printf '%s\n' '  --from-file=redis-ca.crt=certs/redis-ca.crt \'
printf '%s\n' '  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml'
printf "${RESET}"

kubectl create secret generic redis-tls \
  --namespace ${NAMESPACE} \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml

kubectl create secret generic flask-tls \
  --namespace ${NAMESPACE} \
  --from-file=flask.crt=certs/flask.crt \
  --from-file=flask.key=certs/flask.key \
  --from-file=client.crt=certs/client.crt \
  --from-file=client.key=certs/client.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Review the files in `k8s/`, then apply them:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f k8s/secret-redis-tls.yaml'
printf '%s\n' 'kubectl apply -f k8s/secret-flask-tls.yaml'
printf "${RESET}"

kubectl apply -f k8s/secret-redis-tls.yaml
kubectl apply -f k8s/secret-flask-tls.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 5. Generate the manifest from the template'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml'
printf "${RESET}"

tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Review `k8s/manifest.yaml`, then apply it:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}'
printf "${RESET}"

kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 6. Verify the deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Watch all resources come up'
printf '%s\n' 'kubectl get all -n ${NAMESPACE}'
printf '%s\n' ''
printf '%s\n' '# Wait for Redis'
printf '%s\n' 'kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=120s'
printf '%s\n' ''
printf '%s\n' '# Wait for Flask API'
printf '%s\n' 'kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=120s'
printf '%s\n' ''
printf '%s\n' '# Check logs'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=redis --tail=20'
printf "${RESET}"

# Watch all resources come up
kubectl get all -n ${NAMESPACE}

# Wait for Redis
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=120s

# Wait for Flask API
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=120s

# Check logs
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 7. Test the API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the Flask API pod:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl port-forward -n ${NAMESPACE} \'
printf '%s\n' '  $(kubectl get pod -n ${NAMESPACE} -l app=flask-api -o jsonpath='\''{.items[0].metadata.name}'\'') \'
printf '%s\n' '  14996:4996'
printf "${RESET}"

kubectl port-forward -n ${NAMESPACE} \
  $(kubectl get pod -n ${NAMESPACE} -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \
  14996:4996

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then in another terminal, send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# List all stored keys'
printf '%s\n' 'curl -sk https://localhost:14996/keys'
printf '%s\n' ''
printf '%s\n' '# Create a client record'
printf '%s\n' 'curl -sk -X POST https://localhost:14996/client/abc123 \'
printf '%s\n' '  -F fname=John \'
printf '%s\n' '  -F lname=Doe \'
printf '%s\n' '  -F address="123 Main St" \'
printf '%s\n' '  -F city="Springfield" \'
printf '%s\n' '  -F iban="DE89370400440532013000" \'
printf '%s\n' '  -F ssn="123-45-6789" \'
printf '%s\n' '  -F email="john@example.com"'
printf '%s\n' ''
printf '%s\n' '# Retrieve a client'
printf '%s\n' 'curl -sk https://localhost:14996/client/abc123'
printf '%s\n' ''
printf '%s\n' '# Get credit score'
printf '%s\n' 'curl -sk https://localhost:14996/score/abc123'
printf '%s\n' ''
printf '%s\n' '# Memory dump (debug)'
printf '%s\n' 'curl -sk https://localhost:14996/memory'
printf "${RESET}"

# List all stored keys
curl -sk https://localhost:14996/keys

# Create a client record
curl -sk -X POST https://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
curl -sk https://localhost:14996/client/abc123

# Get credit score
curl -sk https://localhost:14996/score/abc123

# Memory dump (debug)
curl -sk https://localhost:14996/memory

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> `-sk` skips TLS verification for the self-signed certificate.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 8. Cleanup'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'kubectl delete namespace ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'rm -f k8s/secret-redis-tls.yaml k8s/secret-flask-tls.yaml k8s/manifest.yaml'
printf "${RESET}"

kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found
kubectl delete namespace ${NAMESPACE} --ignore-not-found
rm -f k8s/secret-redis-tls.yaml k8s/secret-flask-tls.yaml k8s/manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## API Endpoints'
printf '%s\n' ''
printf '%s\n' 'All endpoints are served over HTTPS on port `4996` (mapped to `443` in Kubernetes).'
printf '%s\n' ''
printf '%s\n' '| Method | Path | Description |'
printf '%s\n' '|--------|------|-------------|'
printf '%s\n' '| `POST` | `/client/<client_id>` | Create a new client record |'
printf '%s\n' '| `GET` | `/client/<client_id>` | Retrieve a client by ID |'
printf '%s\n' '| `GET` | `/score/<client_id>` | Get the credit score for a client |'
printf '%s\n' '| `GET` | `/keys` | List all stored client records |'
printf '%s\n' '| `GET` | `/memory` | Dump process memory (debug only) |'
printf "${RESET}"

