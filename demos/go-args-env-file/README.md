# go-args-env-file

A Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. It then sleeps for about 10 seconds before exiting cleanly, mirroring the behavior of a Java reference implementation.

This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a Go application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.

[![go-args-env-file Example](../docs/go-args-env-file.gif)](../docs/go-args-env-file.mp4)

---

## Project layout

```
.
├── main.go                    # application source
├── Makefile                   # build helpers
├── Dockerfile                 # two-stage container image
├── environment-variables.md   # tplenv variable definitions and defaults
└── manifests/
    ├── manifest.template.yaml     # Kubernetes Job/ConfigMap/Secret template (tplenv)
    ├── scone.template.yaml        # SCONE manifest template
    ├── manifest.yaml                  # rendered native manifest
    ├── scone.yaml                     # rendered SCONE manifest
    └── manifest.prod.sanitized.yaml   # produced by scone-td-build
```

---

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- Docker (with push access to your registry)

---

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

---

## 3. Set Up Environment Variables

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Every file reference below goes through `$DEMO_DIR`, this demo's directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/go-args-env-file`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"
# Remove `go-args-env-file-example.json` if it exists.
rm -f "$DEMO_DIR/go-args-env-file-example.json" || true
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
```

Load the full variable set from `environment-variables.md`:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Create the demo namespace if it does not already exist:

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

---

## 4. Build and Push the Native Docker Image

The Dockerfile uses a two-stage build: a `golang:1.22-alpine` builder stage compiles a fully static binary, which is then copied into a minimal `scratch` runtime image.

```bash
# Build the container image.
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
# Push the container image to the registry.
docker push ${NATIVE_IMAGE_NAME}
```

Alternatively, use the Makefile for a local build:

```
# Native build (outputs to bin/go-args-env-file)
make build

# Cross-compile for Linux/amd64
make build GOOS=linux GOARCH=amd64
```

### Makefile targets

| Target  | Description                                      |
|---------|--------------------------------------------------|
| `build` | Compile the binary into `bin/`                   |
| `run`   | Build then execute (pass args with `ARGS="..."`) |
| `tidy`  | Run `go mod tidy`                                |
| `fmt`   | Run `go fmt ./...`                               |
| `vet`   | Run `go vet ./...`                               |
| `test`  | Run `go test ./...`                              |
| `clean` | Remove the `bin/` directory                      |
| `help`  | Print usage summary                              |

---

## 5. Render the Manifests

`tplenv` substitutes environment variables into the template files and writes the final manifests:

```bash
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml" --indent
# Render the template with the selected values.
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml"    --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"    --indent
```

Before applying, confirm that image values were substituted correctly.

---

## 6. Add a Docker Registry Secret

If you need a pull secret for native and confidential images, create it when missing:

```bash
# Check whether the pull secret already exists.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
fi
```

---

## 7. Deploy the Native App

Apply the manifest, wait for the job to complete, and inspect its logs to confirm the app prints arguments, environment variables, and the contents of the ConfigMap and Secret files:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/go-args-env-file -n ${NAMESPACE} --timeout=240s
# Show logs from the Kubernetes workload.
kubectl logs job/go-args-env-file -n ${NAMESPACE}
```

Your container should print the command-line arguments, all environment variables, the contents of `/config/configs.yaml`, and `/config/secrets`.

Clean up the native deployment before moving on:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
```

The manifest mounts:
- `ConfigMap/app-config` → `/config/configs.yaml`
- `Secret/app-secrets`  → `/config/secrets`

---

## 8. Prepare and Apply the SCONE Manifest

First, attest the CAS so the local SCONE CLI has the correct session encryption key. The kubectl path covers an in-cluster CAS; if it fails (typical when `${SCONE_CAS_ADDR}` resolves to an external CAS like `scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${SCONE_CAS_ADDR} -C -G -S \
    || scone cas attest ${SCONE_CAS_ADDR} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any
```

Then build the confidential image and generate the SCONE session from `manifests/scone.yaml`:

```bash
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
```

This command:

- Generates a SCONE session
- Attaches the session to your manifest
- Produces `$DEMO_DIR/manifests/manifest.prod.sanitized.yaml`

---

## 9. Deploy the SCONE-Protected App

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/go-args-env-file -n ${NAMESPACE} --timeout=300s
```

---

## 10. View Logs

```bash
# Show logs from the Kubernetes workload.
kubectl logs job/go-args-env-file -n ${NAMESPACE}
```

---

## 11. Clean Up

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
```

---

## What the app does

1. Prints all **command-line arguments** passed to the binary.
2. Dumps all **environment variables** in the process environment.
3. Reads and prints two files:
   - `/config/configs.yaml` — general configuration (mounted from a `ConfigMap`)
   - `/config/secrets` — secret values (mounted from a Kubernetes `Secret`)
4. **Sleeps for about 10 seconds**, then exits. This is expected, so the Kubernetes workload is modeled as a `Job` rather than a long-running `Deployment`.

---

## Signal handling

The process listens for `SIGINT` and `SIGTERM`. On receipt it prints the signal name to **stderr** and exits immediately, making it suitable for graceful shutdown in containerized environments.
