# SCONE: Governance-approved CAS Policy

This example shows `scone-td-build`'s governance flow: the generated CAS session policies are not signed locally by whoever runs the build. They are submitted to the policy-signing service, approved by the required signers, and the `SignedPolicy` resources are assembled from the signatures the service returns.

The demo proves the approval actually gates the deployment, with two cases:

| Case | What happens |
|---|---|
| **Approved** | every session comes back signed, the CAS accepts the policies, the confidential workload attests and CAS delivers it a secret the policy grants |
| **Refused** | a signer aborts the request, `scone-td-build apply` stops with an error and nothing is produced to deploy |

The app (`app.py`) is deliberately trivial: it just prints the secret CAS hands it. The point of the demo is *how the policy was authorised*.

## How Governance Changes the Flow

Normally `apply` signs the sessions locally (`scone session sign`). With a `remote:` block it instead:

1. submits the assembled sessions (`POST /api/v1/signing-requests`),
2. waits while the signers approve,
3. receives the approved policies plus their signatures, and
4. builds one `SignedPolicy` per session from those signatures.

Governance is **SignedPolicy-only**: keep `encrypted-cas-policy: false`. An encrypted (EPOL) policy under governance is rejected with a clear error.

### The Two Modes

- **Inline governance (used here)**: `remote:` and `access_policy:`. The sessions carry that policy and the service signs the assembled sessions.
- **Remote governance**: `remote:` without `access_policy:`. The service applies the managed policy stored for the API token, and the sessions import the access-policy config-fragment from its `cas-governance` session.

## 1. Prerequisites

- Docker, `python3`, and the `scone` CLI
- A `scone-td-build` binary with governance support
- `tplenv` (`cargo install tplenv --version ">=0.11.0"`)
- For the deploy check: a Kubernetes cluster with the SCONE stack whose CAS matches `${CAS_NAME}.${CAS_NAMESPACE}`, and a SCONE runtime version that matches that CAS
- A token for `registry.scontain.com` (the runtime image is pulled during sconification)

## 2. Set Up Environment Variables

Resolve the directory this demo lives in, so every file reference below works regardless of the caller's current working directory:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/governance`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json" || true
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
```

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
# Load environment variables from the tplenv definition file.
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --eval-export-values --output /dev/null)"

eval "$(tplenv --file "$DEMO_DIR/gov-credential.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --eval-export-values --output /dev/null)"
```

Create the demo namespace if it does not already exist. A fresh namespace per run keeps the CAS session names fresh: re-running into a namespace that already has sessions makes CAS keep the ones it already stored, so a changed policy would not take effect.

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
```

Add the Docker registry pull secret if registry credentials are available:

```bash
# Check whether the pull secret already exists.
if kubectl get secret "$IMAGE_PULL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  kubectl create secret docker-registry "$IMAGE_PULL_SECRET_NAME" \
    --namespace "$NAMESPACE" \
    --docker-server="$REGISTRY" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
fi
```

## 3. Build and Push the Native Image

```bash
# Build the container image.
docker build -t "$IMAGE_NAME" "$DEMO_DIR/app"
# Push the container image to the registry.
docker push "$IMAGE_NAME"
```

## 4. Render the Kubernetes Manifest

```bash
# Render the Kubernetes manifest template.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml"
```

## 5. Case 1 — Approved Policy

Start the stand-in policy-signing service in approve mode. It is a stand-in for the service only: it approves automatically with a single key, but it really signs (it delegates to `scone session sign`), so the signatures, the CAS acceptance and the attestation are all real.

```bash
# Start the governance stand-in in approve mode.
MOCK_PORT=8000
MOCK_LOG="$(mktemp)"
MOCK_POLICY_MODE=APPROVE python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &
MOCK_PID=$!

# Wait for the stand-in process to start listening on the configured port
deadline=$((SECONDS + 15))
server_ready=0

while [ $SECONDS -lt $deadline ]; do
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "governance stand-in exited before it started listening:" >&2
    cat "$MOCK_LOG" >&2
    exit 1
  fi

  # Check if port is open using nc, curl, or bash's built-in /dev/tcp
  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then
    server_ready=1
    break
  fi

  sleep 0.2
done

if [ $server_ready -eq 0 ]; then
  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2
  cat "$MOCK_LOG" >&2
  exit 1
fi
```

Render the SCONE manifest with the dynamic governance URL:

```bash

# Render the SCONE manifest template with the dynamic governance URL.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"
```

Apply the governance flow. This submits the sessions to the stand-in service, waits for approval, and assembles the SignedPolicy resources:

```bash
# Generate the sanitized manifest from the SCONE configuration.
RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml"
```

Verify that every submitted session came back signed:

```bash
# Verify the transformed manifest was produced.
output_manifest="$DEMO_DIR/manifests/manifest.sanitized.yaml"
[ -f "$output_manifest" ] || { echo "FAIL: no transformed manifest was produced"; exit 1; }

# Count SignedPolicy resources and submitted sessions.
signed=$(grep -c 'kind: SignedPolicy' "$output_manifest")
submitted=$(grep -c '^name:' "$DEMO_DIR/manifests/manifest.session.yaml")
[ "$signed" -eq "$submitted" ] || { echo "FAIL: $submitted session(s) submitted but only $signed came back signed"; exit 1; }
echo "PASS: $submitted session(s) submitted -> $signed SignedPolicy resource(s) assembled from the signatures"
```

### Deploy and Verify 

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$output_manifest" -n "$NAMESPACE" 
# Wait for the deployment rollout to complete.
kubectl rollout status deploy/governance-app -n "$NAMESPACE" --timeout=300s

# Poll the logs until the workload reports the governed secret.
log_deadline=$((SECONDS + 120))
logs=""
while [ $SECONDS -lt $log_deadline ]; do
  logs=$(kubectl logs -n "$NAMESPACE" deploy/governance-app --tail=20 2>/dev/null)
  if echo "$logs" | grep -q 'started under a governance-approved policy' && \
      echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy'; then
    break
  fi
  sleep 5
done
echo "$logs" | grep -q 'started under a governance-approved policy' \
  || { echo "$logs"; echo "FAIL: the workload did not report starting under the approved policy"; exit 1; }
echo "$logs" | grep -q 'governed secret = delivered-only-under-the-approved-policy' \
  || { echo "$logs"; echo "FAIL: CAS did not deliver the governed secret to the enclave"; exit 1; }
echo "PASS: the confidential workload attested and received the governed secret"
```

Stop the stand-in before the next case:

```bash
# Stop the governance stand-in.
[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"
```

## 6. Case 2 — Refused Policy

Start the stand-in in abort mode and verify that `apply` fails and produces nothing:

```bash
# Start the governance stand-in in abort mode.
MOCK_LOG="$(mktemp)"
MOCK_POLICY_MODE=REJECT python3 "$DEMO_DIR/app/mock_governance.py" "$MOCK_PORT" >"$MOCK_LOG" 2>&1 &
MOCK_PID=$!

# Wait for the stand-in process to start listening on the configured port
deadline=$((SECONDS + 15))
server_ready=0

while [ $SECONDS -lt $deadline ]; do
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "governance stand-in exited before it started listening:" >&2
    cat "$MOCK_LOG" >&2
    exit 1
  fi

  # Check if port is open using nc, curl, or bash's built-in /dev/tcp
  if (echo > /dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null; then
    server_ready=1
    break
  fi

  sleep 0.2
done

if [ $server_ready -eq 0 ]; then
  echo "governance stand-in did not start listening on port $MOCK_PORT within 15s:" >&2
  cat "$MOCK_LOG" >&2
  exit 1
fi


# Render the SCONE manifest template with the dynamic governance URL.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"

# Copy and Remove any previous sanitized manifest.
cp "$DEMO_DIR/manifests/manifest.sanitized.yaml" "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"

rm -f "$DEMO_DIR/manifests/manifest.sanitized.yaml"

# Run apply and capture output; expect it to fail.
if RUST_LOG=info scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml" 2>&1 | tee /tmp/governance-abort.log; then
  echo "FAIL: apply succeeded even though the signing request was aborted"
  exit 1
fi

# Verify the failure reason.
grep -q 'aborted by a signer' /tmp/governance-abort.log \
  || { echo "FAIL: apply failed, but not because the request was aborted"; exit 1; }

[ ! -f "$DEMO_DIR/manifests/manifest.sanitized.yaml" ] \
  || { echo "FAIL: a transformed manifest was produced for an aborted request"; exit 1; }

echo "PASS: the request was refused, apply stopped and nothing was produced to deploy"
```

## 7. Clean Up

```bash
# Stop the governance stand-in.
[ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
[ -n "${MOCK_LOG:-}" ] && rm -f "$MOCK_LOG"
rm -f /tmp/governance-abort.log

kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.old.sanitized.yaml"
```

## 8. Against the Real Governance Service

Point the demo at your instance instead of the stand-in and drop the stand-in steps:

```bash
export GOVERNANCE_URL="https://<your-policy-signing-service>"
export GOVERNANCE_API_TOKEN="<token bound to your managed access policy>"
```

Render `manifests/scone.template.yaml` with those values and run `scone-td-build apply -f "$DEMO_DIR/manifests/scone.yaml"` directly. The call then **blocks** until the real signers approve the request in the governance website. If the service uses a private CA, add `ca_cert` to the `remote:` block.

## What is Real and What is Simulated

| Real | Simulated |
|---|---|
| the sconified confidential image | the service: one key, automatic approval |
| the signatures (`scone session sign`) | the multi-signer approval workflow |
| CAS accepting the SignedPolicy resources | |
| the enclave attesting and receiving its secret | |
