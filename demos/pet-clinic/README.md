# SCONE PetClinic Demo: Confidential Spring Boot + MariaDB

This demo runs the upstream [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application confidentially inside an Intel SGX enclave using SCONE, backed by a native MariaDB. The Java application (JVM, heap, and the JDBC credentials it uses) is protected inside the enclave and attests to a CAS before it starts; the database runs as a normal Kubernetes workload next to it.


## Architecture

| Component | Mode | Notes |
| --- | --- | --- |
| PetClinic (Spring Boot / JVM) | Confidential (SGX + SCONE) | `java` is the enforced binary; the whole JVM runtime is sconified and attests to the CAS. |
| MariaDB | Native | Deployed directly with `kubectl`, outside the register/apply flow. |
| PetClinic ↔ MariaDB | In-cluster TCP | The confidential app opens a JDBC connection from inside the enclave. |

Only PetClinic is confidential. MariaDB is intentionally native: it keeps its standard entrypoint and initialisation, which the confidential-conversion flow does not need to touch.

## Files

| File | Purpose |
| --- | --- |
| `Dockerfile` | Multi-stage build of PetClinic from a pinned upstream commit. |
| `values.template.yaml` | Defaults for all demo configuration (images, namespace, CAS, DB credentials, `PETCLINIC_REF`); copied to `Values.yaml` on the first run. |
| `../environment-variables.md` | The variables `tplenv` collects (shared by all demos). |
| `manifests/secret.template.yaml` | Database credentials Secret. |
| `manifests/mariadb.template.yaml` | Native MariaDB Deployment and Service. |
| `manifests/petclinic.template.yaml` | Confidential PetClinic Deployment and Service (apply input). |
| `manifests/scone.template.yaml` | `Register` + `Apply` custom resources for `scone-td-build`. |

## 1. Prerequisites

- A Kubernetes cluster with SGX support and the SCONE stack already installed (operator, LAS, and a CAS provisioned).
- `docker`, `kubectl`, `tplenv`, `scone`, and `scone-td-build` on your `PATH`.
- `NATIVE_IMAGE_NAME` set in `Values.yaml` to an image path in a registry you can push to.

## 2. Set Up Environment Variables

Every file reference below goes through `$DEMO_DIR`, this demo's directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory:

```bash
# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/pet-clinic`.
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
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)"
```

Create the demo namespace if it does not already exist:

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

Add the Docker registry pull secret:

```bash
# Check whether the pull secret already exists.
if kubectl get secret -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" \
    --docker-server="${REGISTRY}" \
    --docker-username="${REGISTRY_USER}" \
    --docker-password="${REGISTRY_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
fi
```

Generate the enclave signing key if it does not already exist:

```bash
# Check whether the signing key needs to be generated.
if [ ! -f "$DEMO_DIR/manifests/identity.pem" ]; then
  # Print a status message.
  echo "Generating identity.pem ..."
  # Generate the signing key for confidential binaries.
  openssl genrsa -3 -out "$DEMO_DIR/manifests/identity.pem" 3072
else
  # Print a status message.
  echo "identity.pem already exists."
fi
```

## 3. Build and Push the Native Image

```bash
# Build the container image.
docker build --build-arg "PETCLINIC_REF=$PETCLINIC_REF" -t "$NATIVE_IMAGE_NAME" "$DEMO_DIR"
# Push the container image to the registry.
docker push "$NATIVE_IMAGE_NAME"
```

## 4. Render the Manifests

```bash
tplenv --file "$DEMO_DIR/manifests/secret.template.yaml" --values-file "$DEMO_DIR/Values.yaml"  --create-values-file --output "$DEMO_DIR/manifests/secret.yaml"
tplenv --file "$DEMO_DIR/manifests/mariadb.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/mariadb.yaml"
tplenv --file "$DEMO_DIR/manifests/petclinic.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/petclinic.yaml"
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
```

## 5. Protect the Image with SCONE

```bash
# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
```

## 6. Deploy MariaDB and PetClinic

Deploy the native MariaDB and wait for it:

```bash
# Apply the Kubernetes manifest.
kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/secret.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml"
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/petclinic-db -n "$NAMESPACE" --timeout=300s
```

Then deploy the confidential PetClinic:

```bash
# Apply the Kubernetes manifest.
kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml"
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/petclinic -n "$NAMESPACE" --timeout=600s
```

## 7. Verify the Deployment

```bash
# List the Kubernetes resources in the namespace.
kubectl get pods -n "$NAMESPACE"
```

Check that the application answers over a temporary port-forward:

```bash
# Forward the service port in the background, probe the UI, then stop the port-forward.
kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 3
curl -fsS -o /dev/null -w "PetClinic answered with HTTP %{http_code}\n" http://localhost:8080/ || echo "PetClinic did not answer on http://localhost:8080/"
kill "$PORT_FORWARD_PID" 2>/dev/null || true
```

To browse the UI yourself, keep a port-forward open in a separate terminal (this block is intentionally not part of the generated script):

```text
kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80
```

## 8. Clean Up

Delete the demo resources (the namespace itself is kept, since it may hold the pull secret or other workloads):

```bash
# Delete the Kubernetes resources created by this demo.
kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml" -f "$DEMO_DIR/manifests/secret.yaml"
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=petclinic -n "$NAMESPACE" --timeout=300s || true
```

## Design Notes

A few choices are specific to running a modern JVM confidentially and are worth calling out:

- `unprotected_image: busybox` (the default skip-list). The unprotected image is a skip-list: any binary present in it is left untouched by the sconify step. `java` is dynamically linked against glibc and dlopens the JRE `.so` libraries, so its whole dependency tree must be sconified into the enclave link map. Pointing the skip-list at the JRE base (or the target image itself) would drop those dependencies and the enclave would abort with `libpthread ... not found in the enclave link map`.
- JRE base pinned to glibc 2.39 (`eclipse-temurin:17-jre-noble`). SCONE 6.x ships glibc 2.39. The rolling `17-jre` tag now resolves to a much newer glibc, and that skew breaks the enclave link map for `java`'s direct dependencies. Keeping the base glibc aligned with SCONE avoids it.
- `SCONE_HEAP=4G` + JVM memory caps. The enclave's protected heap must hold the entire JVM footprint. The command bounds the JVM (`-Xmx`, `-XX:MaxMetaspaceSize`, `-XX:CompressedClassSpaceSize`, `-XX:ReservedCodeCacheSize`) so VM initialisation fits inside `SCONE_HEAP`.
- `SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MariaDBDialect`. This is an application-level fix (it is needed with or without SCONE): Hibernate 7.4's dialect auto-detection issues a probe query that references a column MariaDB 11.4 does not have, so the dialect must be pinned explicitly.

## Production Mode

By default the demo runs SGX enclaves in debug mode (`SCONE_PRODUCTION=0`). To run PetClinic as a real production (non-debug) enclave attesting against SCONE's public CAS, set in `Values.yaml`:

```yaml
SCONE_PRODUCTION: '1'
SCONE_CAS_ADDR: scone-cas.cf
```

Then re-run the steps above from section 5 (`scone-td-build from`) onwards. What changes:

- `SCONE_PRODUCTION=1` makes the enclave non-debug. Production enclaves must be signed: section 2 generates an enclave signing key (`manifests/identity.pem`, RSA-3072) on first use, which has to be passed to the sconify step via `SCONE_KEY`. That key is the MRSIGNER of your image; keep it private (it is git-ignored).
- `scone-cas.cf` is SCONE's public CAS. The policy is signed locally (`spol`) and uploaded there.

Caveats:

- `scone-cas.cf` is itself a debug CAS, so it is accepted with `--only_for_testing-debug`. A fully production trust chain needs a CAS provisioned in production mode.
- Only PetClinic reaches production here. The optional confidential MariaDB variant (`conf-mariadb/`) uses SCONE product images that are debug-signed, so it cannot run with `SCONE_PRODUCTION=1` (it fails with `Cannot sign production enclave: no key provided`). It runs in debug mode only.

