# java-args-env-file (Java)

A Java utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. It then sleeps for 1 hour (keeping a container alive) before exiting cleanly.

This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a SCONE-enabled Java application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.

---

## Project layout

```
.
├── app/
│   ├── Main.java              # application source
│   └── Dockerfile             # two-stage image: JDK builder → JRE runtime
├── manifests/
│   ├── manifest.template.yaml          # Kubernetes Job + ConfigMap + Secret template (tplenv)
│   ├── scone.template.yaml             # SCONE manifest template
│   ├── manifest.yaml                   # rendered native manifest (generated)
│   ├── scone.yaml                      # rendered SCONE manifest (generated)
│   └── manifest.prod.sanitized.yaml    # produced by scone-td-build (generated)
├── values.template.yaml       # default values, copied to Values.yaml on first run
└── README.md
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
export SIGNER="$(scone self show-session-signing-key)"
```

Every file reference below goes through `$DEMO_DIR`, this demo's directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory. Then clean up state left over from a previous run:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/java-args-env-file`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json" || true
```

Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:

```bash
# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
```

Load the full variable set from `environment-variables.md`:

```bash
eval $(tplenv --file "$DEMO_DIR/../environment-variables.md" --create-values-file --values-file "$DEMO_DIR/Values.yaml"  --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
```

> **Note:** All commands in the following sections assume these environment variables are exported in your current shell session. If you open a new terminal, re-run the `export SIGNER` and `eval $(tplenv ...)` commands above before proceeding.

---

## 4. Build and Push the Native Docker Image

The Dockerfile uses a two-stage build: an `eclipse-temurin:21-jdk-alpine` builder stage compiles `Main.java`, and the resulting `.class` file is copied into a minimal `eclipse-temurin:21-jre-alpine` runtime image.

```bash
docker build -t ${NATIVE_IMAGE_NAME} "$DEMO_DIR/app"
docker push ${NATIVE_IMAGE_NAME}
```

---

## 5. Render the Manifests

`tplenv` substitutes environment variables into the template files and writes the final manifests:

```bash
tplenv --file "$DEMO_DIR/manifests/manifest.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/manifest.yaml" --indent
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml" --values-file "$DEMO_DIR/Values.yaml"    --create-values-file --output "$DEMO_DIR/manifests/scone.yaml"    --indent
```

Before applying, confirm that image values were substituted correctly.

---

## 6. Add a Docker Registry Secret

If you need a pull secret for native and confidential images, create it when missing:

```bash
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching of namespace ${NAMESPACE} failed -- ignoring this"

if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

---

## 7. Deploy the Native App

Apply the manifest and follow the pod logs to confirm the app prints arguments, environment variables, and the contents of the ConfigMap and Secret files:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f "$DEMO_DIR/manifests/manifest.yaml" -n ${NAMESPACE}
# Follow logs from the Kubernetes workload.
retry-spinner --retries 10 --wait 2 -- kubectl logs deployment/java-args-env-file -n "${NAMESPACE}" --follow
```

Your container should print the command-line args, all environment variables, the contents of `/config/configs.yaml`, and `/config/secrets`.

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
kubectl scone cas attest --namespace "${SCONE_CAS_ADDR#*.}" "${SCONE_CAS_ADDR%%.*}" -C -G -S \
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
```

---

## 10. View Logs

```bash
# Follow logs from the Kubernetes workload.
retry-spinner -- kubectl logs deployment/java-args-env-file -n "${NAMESPACE}" --follow
```

---

## 11. Clean Up

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -n ${NAMESPACE}
```

---

## What the app does

1. Prints all **command-line arguments** passed to `main(String[] args)`.
2. Dumps all **environment variables** via `System.getenv()`.
3. Reads and prints two files using `Files.lines()`:
   - `/config/configs.yaml` — general configuration (mounted from a `ConfigMap`)
   - `/config/secrets` — secret values (mounted from a Kubernetes `Secret`)
4. **Sleeps for 1 hour**, then exits. Handles `InterruptedException` gracefully (reports to stderr and exits early).

---

## Signal handling

The JVM catches `InterruptedException` during `Thread.sleep()`. On interruption it prints the exception message to **stderr** and exits, making it suitable for graceful shutdown in containerised environments.
