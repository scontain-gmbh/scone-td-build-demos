# flask-redis

A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.

## Project Structure

```
flask-redis/
├── app.py                  # Flask application
├── Dockerfile              # Flask image build
├── requirements.txt        # Python dependencies
├── deploy.sh               # Automated deploy + test script
├── k8s/
│   └── manifest.template.yaml  # Redis + Flask API deployment template
└── README.md
```

---

## Deploy

There are two ways to deploy: run the **automated script** (recommended) or follow the **manual steps** below.

---

### Option A — Automated script

The `deploy.sh` script handles everything end-to-end: TLS cert generation, Docker build and push, Kubernetes secret and manifest generation, deployment, and integration tests via port-forward. It also cleans up all deployed resources when it finishes (or if something goes wrong).

#### Usage

```
Usage: ./deploy.sh --image <IMAGE> [--certs <CERTS_DIR>] [--k8s <K8S_DIR>] [--namespace <NAMESPACE>]

Flags:
  -i, --image        Image name (required), e.g. myregistry/flask-redis-api:latest
  --certs            Path to certs directory (default: <script-dir>/certs)
  --k8s              Path to k8s manifests directory (default: <script-dir>/k8s)
  -n, --namespace    Kubernetes namespace (default: flask-redis)
```

#### Example

```
chmod +x deploy.sh
./deploy.sh --image myregistry/flask-redis-api:latest
```

With custom paths:

```
./deploy.sh \
  --image myregistry/flask-redis-api:latest \
  --certs ./my-certs \
  --k8s ./k8s \
  --namespace flask-redis
```

The script will pause after generating the secret and manifest YAML files in `--k8s` so you can inspect them before anything is applied to the cluster. After the tests finish, all deployed resources are automatically removed.

---

### Option B — Manual steps

#### Prerequisites

- `kubectl` configured for your cluster
- `docker` with access to a registry your cluster can pull from
- `openssl` and `tplenv` available in your shell

---

#### 1. Generate TLS certificates

```bash
cd flask-redis
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
```

| File | Used by | Purpose |
|---|---|---|
| `redis-ca.crt` | Both | CA that signed all certs |
| `redis.crt` / `redis.key` | Redis | Redis server cert/key |
| `flask.crt` / `flask.key` | Flask | Flask HTTPS server cert/key |
| `client.crt` / `client.key` | Flask | mTLS client cert for Redis |

---

#### 2. Build and push the Docker image

First, let `tplenv` query all environment variables used by this example:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Then build and push the Docker image:

```bash
docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}
```

---

#### 3. Create the namespace

```bash
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
```

---

#### 4. Generate and inspect secret manifests

Generate the secret YAML files locally so you can inspect them before applying:

```bash
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
```

Review the files in `k8s/`, then apply them:

```bash
kubectl apply -f k8s/secret-redis-tls.yaml
kubectl apply -f k8s/secret-flask-tls.yaml
```

---

## 5. Add Docker Registry Secret to Kubernetes

We assume you need a pull secret to pull both the native and confidential container images. First, we check whether the pull secret is already set. If it is not, we ask the user for the information needed to create it:

- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.
- `$REGISTRY_USER` - the login name of the user that pulls the container image.
- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.

Note that `tplenv` stores this information in `Values.yaml`.

```bash
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists in namespace ${NAMESPACE}"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist in namespace ${NAMESPACE} - creating now."
  # ask user for the credentials for accessing the registry
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
  kubectl create secret docker-registry -n ${NAMESPACE} "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```


#### 6. Generate the manifest from the template

```bash
tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml
```

Review `k8s/manifest.yaml`, then apply it:

```bash
kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}
```

---

#### 7. Verify the deployment

```bash
# Watch all resources come up
kubectl get all -n ${NAMESPACE}

# Wait for Redis
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=120s

# Wait for Flask API
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=120s

# Check logs
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
```

---

#### 8. Test the API via port-forward

Open a port-forward to the Flask API pod:

```bash
kubectl port-forward -n ${NAMESPACE} \
  $(kubectl get pod -n ${NAMESPACE} -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \
  14996:4996 &  echo $! > /tmp/pf-14996.pid
```

Then in another terminal, send requests against `https://localhost:14996`:

```bash
# List all stored keys
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys

# Create a client record
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk -X POST https://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk https://localhost:14996/client/abc123

# Get credit score
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk https://localhost:14996/score/abc123

# Memory dump (debug)
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory
```

> `-sk` skips TLS verification for the self-signed certificate.

---

#### 9. Cleanup

```bash
kubectl delete -f k8s/manifest.yaml --ignore-not-found
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found
rm -f k8s/secret-redis-tls.yaml k8s/secret-flask-tls.yaml k8s/manifest.yaml
kill $(cat /tmp/pf-14996.pid) || true
rm /tmp/pf-14996.pid
```

---

## API Endpoints

All endpoints are served over HTTPS on port `4996` (mapped to `443` in Kubernetes).

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/client/<client_id>` | Create a new client record |
| `GET` | `/client/<client_id>` | Retrieve a client by ID |
| `GET` | `/score/<client_id>` | Get the credit score for a client |
| `GET` | `/keys` | List all stored client records |
| `GET` | `/memory` | Dump process memory (debug only) |
