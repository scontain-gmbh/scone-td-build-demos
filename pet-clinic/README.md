# pet-clinic (Spring Boot + MariaDB)

This demo runs the upstream [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application confidentially inside an Intel SGX enclave using SCONE, backed by a native MariaDB. The Java application (JVM, heap, and the JDBC credentials it uses) is protected inside the enclave and attests to a CAS before it starts; the database runs as a normal Kubernetes workload next to it.

---

## Architecture

| Component | Mode | Notes |
| --- | --- | --- |
| PetClinic (Spring Boot / JVM) | Confidential (SGX + SCONE) | `java` is the enforced binary; the whole JVM runtime is sconified and attests to the CAS. |
| MariaDB | Native | Deployed directly with `kubectl`, outside the register/apply flow. |
| PetClinic ↔ MariaDB | In-cluster TCP | The confidential app opens a JDBC connection from inside the enclave. |

Only PetClinic is confidential. MariaDB is intentionally native: it keeps its standard entrypoint and initialisation, which the confidential-conversion flow does not need to touch.

## Project layout

```
.
├── Dockerfile                  # multi-stage build of PetClinic from a pinned upstream commit
├── environment-variables.md    # tplenv variable definitions
├── Values.yaml                 # default values
└── manifests/
    ├── secret.template.yaml        # database credentials Secret
    ├── mariadb.template.yaml       # native MariaDB Deployment and Service
    ├── petclinic.template.yaml     # PetClinic Deployment and Service (apply input)
    ├── scone.template.yaml         # Register + Apply manifest for scone-td-build
    └── manifest.prod.sanitized.yaml    # produced by scone-td-build
```

---

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX support and the SCONE stack installed (operator, LAS, and a CAS)
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- Docker (with push access to your registry)

---

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

---

## 3. Set Up Environment Variables

Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:

- `$IMAGE_NAME` - Name of the native PetClinic image
- `$DESTINATION_IMAGE_NAME` - Name of the confidential (SCONE-protected) image
- `$PETCLINIC_REF` - Upstream Spring PetClinic commit the image is built from
- `$MARIADB_IMAGE` - Native MariaDB image (default: `mariadb:11.4`)
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)
- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.0.8`)
- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)
- `$CAS_NAME` - CAS name (for example, `cas`)
- `$CAS_ENDPOINT` - Address the manifest targets; keep it in sync with `$CAS_NAME`.`$CAS_NAMESPACE` (default: `cas.default`), or set to an external CAS address to run against one
- `$TEE_TYPE` - Set to `cvm` for CVM mode or `sgx` for SGX
- `$SCONE_ENCLAVE` - In CVM mode, set to `true` for confidential nodes, or `false` for Kata Pods
- `$NAMESPACE` - namespace name (default: `pet-clinic`)
- `$ENCLAVE_HEAP` - Enclave heap of the PetClinic container (default: `4G`)
- `$DB_NAME`, `$DB_USER`, `$DB_PASSWORD`, `$DB_ROOT_PASSWORD` - MariaDB database and credentials

Assume you start in `scone-td-build-demos` and switch into this demo directory:

```bash
# Change into `pet-clinic`.
pushd pet-clinic
# Remove the state file of an earlier run, if it exists.
rm -f pet-clinic-demo.json || true
```

Set `SIGNER` for policy signing:

```bash
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
```

> **Note:** All commands in the following sections assume these environment variables are exported in your current shell session. If you open a new terminal, re-run the `export SIGNER` and `eval $(tplenv ...)` commands above before proceeding.

---

## 4. Build and Push the Native Image

The Dockerfile clones Spring PetClinic at `$PETCLINIC_REF`, builds the jar with Maven, and copies it into an `eclipse-temurin:17-jre-noble` runtime image.

```bash
# Build the container image.
docker build --build-arg "PETCLINIC_REF=${PETCLINIC_REF}" -t ${IMAGE_NAME} .
# Push the container image to the registry.
docker push ${IMAGE_NAME}
```

---

## 5. Render the Manifests

`tplenv` substitutes environment variables into the template files and writes the final manifests:

```bash
tplenv --file manifests/secret.template.yaml    --create-values-file --output manifests/secret.yaml
tplenv --file manifests/mariadb.template.yaml   --create-values-file --output manifests/mariadb.yaml
tplenv --file manifests/petclinic.template.yaml --create-values-file --output manifests/petclinic.yaml
tplenv --file manifests/scone.template.yaml     --create-values-file --output manifests/scone.yaml --indent
```

---

## 6. Add a Docker Registry Secret

The pull secret is refreshed with the credentials selected by `tplenv`.
Inside the SCONE toolbox, setup loads its mounted registry credentials first.
Saved overrides belong in the ignored `Values.credentials.yaml`; empty registry
fields in the shared `Values.yaml` must not mask the toolbox credentials.
The namespace must already exist when running with the toolbox service account;
`k8s_cli.sh` provisions the standard demo namespaces and scoped roles.

- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` - Registry login name
- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  if ! kubectl create namespace "$NAMESPACE"; then
    echo "Namespace $NAMESPACE is unavailable. Run toolbox setup using a cluster administrator first." >&2
    exit 1
  fi
fi

source ../scripts/load-registry-credentials.sh
read -r -a registry_confirmation_options <<< "${CONFIRM_ALL_ENVIRONMENT_VARIABLES-}"
registry_values_temporary="$(mktemp Values.credentials.yaml.XXXXXX)"
# The temporary file holds the token; remove it even if this step is interrupted.
trap 'rm -f "$registry_values_temporary"' EXIT
if [[ -f Values.credentials.yaml ]]; then
  cp -p Values.credentials.yaml "$registry_values_temporary"
fi
if registry_exports="$(tplenv --values "$registry_values_temporary" --file registry.credentials.md --create-values-file --eval "${registry_confirmation_options[@]}")"; then
  eval "$registry_exports"
  if [[ -z "${REGISTRY:-}" || -z "${REGISTRY_USER:-}" || -z "${REGISTRY_TOKEN:-}" ]]; then
    rm -f "$registry_values_temporary"
    echo "Registry credentials are incomplete. Run this demo interactively or configure Values.credentials.yaml." >&2
    exit 1
  fi
  chmod 600 "$registry_values_temporary"
  mv -f "$registry_values_temporary" Values.credentials.yaml
else
  rm -f "$registry_values_temporary"
  exit 1
fi

trap - EXIT

# Pass the credentials on stdin: as command-line flags the token would be visible in `ps`.
registry_auth="$(printf '%s:%s' "$REGISTRY_USER" "$REGISTRY_TOKEN" | base64 | tr -d '\n')"
printf '{"auths":{"%s":{"username":"%s","password":"%s","auth":"%s"}}}' \
  "$REGISTRY" "$REGISTRY_USER" "$REGISTRY_TOKEN" "$registry_auth" \
  | kubectl create secret generic -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" \
      --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin \
      --dry-run=client -o yaml \
  | kubectl apply -n "$NAMESPACE" -f -
unset registry_auth
```

---

## 7. Deploy MariaDB

Deploy the database credentials and the native MariaDB, and wait for it:

```bash
# Apply the Kubernetes manifests.
kubectl apply -n "$NAMESPACE" -f manifests/secret.yaml -f manifests/mariadb.yaml
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/petclinic-db -n "$NAMESPACE" --timeout=300s
```

---

## 8. Protect PetClinic with SCONE

First, attest the CAS so the local SCONE CLI has the correct session encryption key. The kubectl path covers an in-cluster CAS; if it fails (typical when `${CAS_ENDPOINT}` points at an external CAS like `edge.scone-cas.cf`), the second branch attests the public CAS directly.

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S \
    || scone cas attest ${CAS_ENDPOINT} -C -G -S \
        --only_for_testing-debug --only_for_testing-ignore-signer --only_for_testing-trust-any \
    || echo "CAS attestation skipped: ${CAS_ENDPOINT} runs in simulation mode, so it cannot produce a DCAP quote"
```

Then build the confidential image and generate the SCONE session from `manifests/scone.yaml`:

```bash
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build apply -f manifests/scone.yaml
```

This command:

- Sconifies `java` and its dependencies into the confidential image and pushes it to `$DESTINATION_IMAGE_NAME`
- Generates a SCONE session that holds the datasource credentials from the Secret
- Produces `manifests/manifest.prod.sanitized.yaml`

---

## 9. Deploy the Confidential PetClinic

```bash
# Apply the Kubernetes manifest.
kubectl apply -n "$NAMESPACE" -f manifests/manifest.prod.sanitized.yaml
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/petclinic -n "$NAMESPACE" --timeout=600s
```

---

## 10. Verify the Deployment

```bash
# List the pods in the namespace.
kubectl get pods -n "$NAMESPACE"
```

Check that the application answers over a temporary port-forward:

```bash
# Forward the service port in the background.
kubectl port-forward -n "$NAMESPACE" svc/petclinic 18080:80 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
# Stop the port-forward even if the check below fails.
trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT
# Probe the UI until it answers.
retry-spinner --retries 20 --wait 3 -- curl -fsS -o /dev/null http://localhost:18080/
echo "PetClinic answered on http://localhost:18080/"
kill "$PORT_FORWARD_PID" 2>/dev/null || true
trap - EXIT
```

To browse the UI yourself, keep a port-forward open in a separate terminal (this block is intentionally not part of the generated script):

```text
kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80
```

---

## 11. Clean Up

Delete the demo resources (the namespace itself is kept, since it holds the pull secret):

```bash
# Delete the Kubernetes resources created by this demo.
kubectl delete -n "$NAMESPACE" --ignore-not-found -f manifests/manifest.prod.sanitized.yaml -f manifests/mariadb.yaml -f manifests/secret.yaml
# Wait for the pods to be deleted.
kubectl wait --for=delete pod -l app=petclinic -n "$NAMESPACE" --timeout=300s || true
# Return to the previous working directory.
popd
```

---

## Design Notes

A few choices are specific to running a modern JVM confidentially:

- `reference-image: busybox`. The reference image is a skip-list: any binary present in it is left untouched by the sconify step. `java` is dynamically linked against glibc and dlopens the JRE `.so` libraries, so its whole dependency tree must be sconified into the enclave link map. Pointing the skip-list at the JRE base (or the target image itself) would drop those dependencies and the enclave would abort with `libpthread ... not found in the enclave link map`.
- JRE base pinned to glibc 2.39 (`eclipse-temurin:17-jre-noble`). SCONE 6.x ships glibc 2.39. The rolling `17-jre` tag now resolves to a much newer glibc, and that skew breaks the enclave link map for `java`'s direct dependencies. Keeping the base glibc aligned with SCONE avoids it.
- `ENCLAVE_HEAP=4G` and JVM memory caps. The enclave's protected heap must hold the entire JVM footprint. The command bounds the JVM (`-Xmx`, `-XX:MaxMetaspaceSize`, `-XX:CompressedClassSpaceSize`, `-XX:ReservedCodeCacheSize`) so VM initialisation fits inside the heap.
- `SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MariaDBDialect`. This is an application-level fix (it is needed with or without SCONE): Hibernate 7.4's dialect auto-detection issues a probe query that references a column MariaDB 11.4 does not have, so the dialect must be pinned explicitly.
