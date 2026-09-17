#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from demos/pet-clinic/README.md.

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

if ! $NON_INTERACTIVE; then
  CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory of the README this script was generated from. The README
# code blocks use it for every file reference so the script works from
# any working directory.
export DEMO_DIR="$(cd "${script_dir}/../../demos/pet-clinic" && pwd)"

printf "${VIOLET}"
printf '%s\n' '# SCONE PetClinic Demo: Confidential Spring Boot + MariaDB'
printf '%s\n' ''
printf '%s\n' 'This demo runs the upstream [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application confidentially inside an Intel SGX enclave using SCONE, backed by a native MariaDB. The Java application (JVM, heap, and the JDBC credentials it uses) is protected inside the enclave and attests to a CAS before it starts; the database runs as a normal Kubernetes workload next to it.'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '## Architecture'
printf '%s\n' ''
printf '%s\n' '| Component | Mode | Notes |'
printf '%s\n' '| --- | --- | --- |'
printf '%s\n' '| PetClinic (Spring Boot / JVM) | Confidential (SGX + SCONE) | `java` is the enforced binary; the whole JVM runtime is sconified and attests to the CAS. |'
printf '%s\n' '| MariaDB | Native | Deployed directly with `kubectl`, outside the register/apply flow. |'
printf '%s\n' '| PetClinic ↔ MariaDB | In-cluster TCP | The confidential app opens a JDBC connection from inside the enclave. |'
printf '%s\n' ''
printf '%s\n' 'Only PetClinic is confidential. MariaDB is intentionally native: it keeps its standard entrypoint and initialisation, which the confidential-conversion flow does not need to touch.'
printf '%s\n' ''
printf '%s\n' '## Files'
printf '%s\n' ''
printf '%s\n' '| File | Purpose |'
printf '%s\n' '| --- | --- |'
printf '%s\n' '| `Dockerfile` | Multi-stage build of PetClinic from a pinned upstream commit. |'
printf '%s\n' '| `values.template.yaml` | Defaults for all demo configuration (images, namespace, CAS, DB credentials, `PETCLINIC_REF`); copied to `Values.yaml` on the first run. |'
printf '%s\n' '| `../environment-variables.md` | The variables `tplenv` collects (shared by all demos). |'
printf '%s\n' '| `manifests/secret.template.yaml` | Database credentials Secret. |'
printf '%s\n' '| `manifests/mariadb.template.yaml` | Native MariaDB Deployment and Service. |'
printf '%s\n' '| `manifests/petclinic.template.yaml` | Confidential PetClinic Deployment and Service (apply input). |'
printf '%s\n' '| `manifests/scone.template.yaml` | `Register` + `Apply` custom resources for `scone-td-build`. |'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A Kubernetes cluster with SGX support and the SCONE stack already installed (operator, LAS, and a CAS provisioned).'
printf '%s\n' '- `docker`, `kubectl`, `tplenv`, `scone`, and `scone-td-build` on your `PATH`.'
printf '%s\n' '- `NATIVE_IMAGE_NAME` set in `Values.yaml` to an image path in a registry you can push to.'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Every file reference below goes through `$DEMO_DIR`, this demo'\''s directory. The generated scripts set it for you; when following this README by hand, run the commands from this directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# The generated scripts set DEMO_DIR to this demo'\''s directory. When following'
printf '%s\n' '# this README by hand, run the commands from `demos/pet-clinic`.'
printf '%s\n' 'export DEMO_DIR="${DEMO_DIR:-$PWD}"'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm -f "$DEMO_DIR/manifests/storage.json" || true'
printf "${RESET}"

# The generated scripts set DEMO_DIR to this demo's directory. When following
# this README by hand, run the commands from `demos/pet-clinic`.
export DEMO_DIR="${DEMO_DIR:-$PWD}"
# Remove `storage.json` if it exists.
rm -f "$DEMO_DIR/manifests/storage.json" || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Seed Values.yaml from the template on first run only.'
printf '%s\n' '[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"'
printf "${RESET}"

# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Export the required environment variable for the next steps.'
printf '%s\n' 'export SIGNER="$(scone self show-session-signing-key)"'
printf "${RESET}"

# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)"'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the Kubernetes namespace if it does not already exist.'
printf '%s\n' 'kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"'
printf "${RESET}"

# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Add the Docker registry pull secret:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the pull secret already exists.'
printf '%s\n' 'if kubectl get secret -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" >/dev/null 2>&1; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  # Create the Docker registry pull secret.'
printf '%s\n' '  kubectl create secret docker-registry -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" \'
printf '%s\n' '    --docker-server="${REGISTRY}" \'
printf '%s\n' '    --docker-username="${REGISTRY_USER}" \'
printf '%s\n' '    --docker-password="${REGISTRY_TOKEN}" \'
printf '%s\n' '    --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -'
printf '%s\n' 'fi'
printf "${RESET}"

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

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate the enclave signing key if it does not already exist:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the signing key needs to be generated.'
printf '%s\n' 'if [ ! -f "$DEMO_DIR/manifests/identity.pem" ]; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  # Generate the signing key for confidential binaries.'
printf '%s\n' '  openssl genrsa -3 -out "$DEMO_DIR/manifests/identity.pem" 3072'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

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

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Build and Push the Native Image'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build --build-arg "PETCLINIC_REF=$PETCLINIC_REF" -t "$NATIVE_IMAGE_NAME" "$DEMO_DIR"'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push "$NATIVE_IMAGE_NAME"'
printf "${RESET}"

# Build the container image.
docker build --build-arg "PETCLINIC_REF=$PETCLINIC_REF" -t "$NATIVE_IMAGE_NAME" "$DEMO_DIR"
# Push the container image to the registry.
docker push "$NATIVE_IMAGE_NAME"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Render the Manifests'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/secret.template.yaml" --values-file "$DEMO_DIR/Values.yaml"  --create-values-file --output "$DEMO_DIR/manifests/secret.yaml"'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/mariadb.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/mariadb.yaml"'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/petclinic.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/petclinic.yaml"'
printf '%s\n' 'tplenv --file "$DEMO_DIR/manifests/scone.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent'
printf "${RESET}"

tplenv --file "$DEMO_DIR/manifests/secret.template.yaml" --values-file "$DEMO_DIR/Values.yaml"  --create-values-file --output "$DEMO_DIR/manifests/secret.yaml"
tplenv --file "$DEMO_DIR/manifests/mariadb.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/mariadb.yaml"
tplenv --file "$DEMO_DIR/manifests/petclinic.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/petclinic.yaml"
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Protect the Image with SCONE'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Generate the confidential image and sanitized manifest from the SCONE configuration.'
printf '%s\n' '(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)'
printf "${RESET}"

# Generate the confidential image and sanitized manifest from the SCONE configuration.
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Deploy MariaDB and PetClinic'
printf '%s\n' ''
printf '%s\n' 'Deploy the native MariaDB and wait for it:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/secret.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml"'
printf '%s\n' '# Wait for the deployment rollout to complete.'
printf '%s\n' 'kubectl rollout status deployment/petclinic-db -n "$NAMESPACE" --timeout=300s'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/secret.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml"
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/petclinic-db -n "$NAMESPACE" --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then deploy the confidential PetClinic:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml"'
printf '%s\n' '# Wait for the deployment rollout to complete.'
printf '%s\n' 'kubectl rollout status deployment/petclinic -n "$NAMESPACE" --timeout=600s'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml"
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/petclinic -n "$NAMESPACE" --timeout=600s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Verify the Deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# List the Kubernetes resources in the namespace.'
printf '%s\n' 'kubectl get pods -n "$NAMESPACE"'
printf "${RESET}"

# List the Kubernetes resources in the namespace.
kubectl get pods -n "$NAMESPACE"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Check that the application answers over a temporary port-forward:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Forward the service port in the background, probe the UI, then stop the port-forward.'
printf '%s\n' 'kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80 >/dev/null 2>&1 &'
printf '%s\n' 'PORT_FORWARD_PID=$!'
printf '%s\n' 'sleep 3'
printf '%s\n' 'curl -fsS -o /dev/null -w "PetClinic answered with HTTP %{http_code}\n" http://localhost:8080/ || echo "PetClinic did not answer on http://localhost:8080/"'
printf '%s\n' 'kill "$PORT_FORWARD_PID" 2>/dev/null || true'
printf "${RESET}"

# Forward the service port in the background, probe the UI, then stop the port-forward.
kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 3
curl -fsS -o /dev/null -w "PetClinic answered with HTTP %{http_code}\n" http://localhost:8080/ || echo "PetClinic did not answer on http://localhost:8080/"
kill "$PORT_FORWARD_PID" 2>/dev/null || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'To browse the UI yourself, keep a port-forward open in a separate terminal (this block is intentionally not part of the generated script):'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80'
printf '%s\n' ''
printf '%s\n' '## 8. Clean Up'
printf '%s\n' ''
printf '%s\n' 'Delete the demo resources (the namespace itself is kept, since it may hold the pull secret or other workloads):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resources created by this demo.'
printf '%s\n' 'kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml" -f "$DEMO_DIR/manifests/secret.yaml"'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=petclinic -n "$NAMESPACE" --timeout=300s || true'
printf "${RESET}"

# Delete the Kubernetes resources created by this demo.
kubectl delete -n "$NAMESPACE" --ignore-not-found -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml" -f "$DEMO_DIR/manifests/secret.yaml"
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=petclinic -n "$NAMESPACE" --timeout=300s || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Design Notes'
printf '%s\n' ''
printf '%s\n' 'A few choices are specific to running a modern JVM confidentially and are worth calling out:'
printf '%s\n' ''
printf '%s\n' '- `unprotected_image: busybox` (the default skip-list). The unprotected image is a skip-list: any binary present in it is left untouched by the sconify step. `java` is dynamically linked against glibc and dlopens the JRE `.so` libraries, so its whole dependency tree must be sconified into the enclave link map. Pointing the skip-list at the JRE base (or the target image itself) would drop those dependencies and the enclave would abort with `libpthread ... not found in the enclave link map`.'
printf '%s\n' '- JRE base pinned to glibc 2.39 (`eclipse-temurin:17-jre-noble`). SCONE 6.x ships glibc 2.39. The rolling `17-jre` tag now resolves to a much newer glibc, and that skew breaks the enclave link map for `java`'\''s direct dependencies. Keeping the base glibc aligned with SCONE avoids it.'
printf '%s\n' '- `SCONE_HEAP=4G` + JVM memory caps. The enclave'\''s protected heap must hold the entire JVM footprint. The command bounds the JVM (`-Xmx`, `-XX:MaxMetaspaceSize`, `-XX:CompressedClassSpaceSize`, `-XX:ReservedCodeCacheSize`) so VM initialisation fits inside `SCONE_HEAP`.'
printf '%s\n' '- `SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MariaDBDialect`. This is an application-level fix (it is needed with or without SCONE): Hibernate 7.4'\''s dialect auto-detection issues a probe query that references a column MariaDB 11.4 does not have, so the dialect must be pinned explicitly.'
printf '%s\n' ''
printf '%s\n' '## Production Mode'
printf '%s\n' ''
printf '%s\n' 'By default the demo runs SGX enclaves in debug mode (`SCONE_PRODUCTION=0`). To run PetClinic as a real production (non-debug) enclave attesting against SCONE'\''s public CAS, set in `Values.yaml`:'
printf '%s\n' ''
printf '%s\n' 'SCONE_PRODUCTION: '\''1'\'''
printf '%s\n' 'SCONE_CAS_ADDR: scone-cas.cf'
printf '%s\n' ''
printf '%s\n' 'Then re-run the steps above from section 5 (`scone-td-build from`) onwards. What changes:'
printf '%s\n' ''
printf '%s\n' '- `SCONE_PRODUCTION=1` makes the enclave non-debug. Production enclaves must be signed: section 2 generates an enclave signing key (`manifests/identity.pem`, RSA-3072) on first use, which has to be passed to the sconify step via `SCONE_KEY`. That key is the MRSIGNER of your image; keep it private (it is git-ignored).'
printf '%s\n' '- `scone-cas.cf` is SCONE'\''s public CAS. The policy is signed locally (`spol`) and uploaded there.'
printf '%s\n' ''
printf '%s\n' 'Caveats:'
printf '%s\n' ''
printf '%s\n' '- `scone-cas.cf` is itself a debug CAS, so it is accepted with `--only_for_testing-debug`. A fully production trust chain needs a CAS provisioned in production mode.'
printf '%s\n' '- Only PetClinic reaches production here. The optional confidential MariaDB variant (`conf-mariadb/`) uses SCONE product images that are debug-signed, so it cannot run with `SCONE_PRODUCTION=1` (it fails with `Cannot sign production enclave: no key provided`). It runs in debug mode only.'
printf '%s\n' ''
printf "${RESET}"

