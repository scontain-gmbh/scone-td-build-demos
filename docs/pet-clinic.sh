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

Runs a demo-style shell script generated from demos/pet-clinic/README.md.

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
# Directory of the README this script was generated from. The README
# code blocks use it for every file reference so the script works from
# any working directory.
export DEMO_DIR="$(cd "${script_dir}/../demos/pet-clinic" && pwd)"

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# The generated scripts set DEMO_DIR to this demo's directory. When following
EOF
)"
pe "$(cat <<'EOF'
# this README by hand, run the commands from `demos/pet-clinic`.
EOF
)"
pe "$(cat <<'EOF'
export DEMO_DIR="${DEMO_DIR:-$PWD}"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Default values live in `$DEMO_DIR/values.template.yaml`. Copy it to `Values.yaml` if that file does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Seed Values.yaml from the template on first run only.
EOF
)"
pe "$(cat <<'EOF'
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Export the required environment variable for the next steps.
EOF
)"
pe "$(cat <<'EOF'
export SIGNER="$(scone self show-session-signing-key)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --context --eval --eval-export-values ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Create the demo namespace if it does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Kubernetes namespace if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Add the Docker registry pull secret:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
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
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  # Create the Docker registry pull secret.
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry -n "$NAMESPACE" "$IMAGE_PULL_SECRET_NAME" \
    --docker-server="${REGISTRY}" \
    --docker-username="${REGISTRY_USER}" \
    --docker-password="${REGISTRY_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate the enclave signing key if it does not already exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the signing key needs to be generated.
EOF
)"
pe "$(cat <<'EOF'
if [ ! -f "$DEMO_DIR/manifests/identity.pem" ]; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Generating identity.pem ..."
EOF
)"
pe "$(cat <<'EOF'
  # Generate the signing key for confidential binaries.
EOF
)"
pe "$(cat <<'EOF'
  openssl genrsa -3 -out "$DEMO_DIR/manifests/identity.pem" 3072
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "identity.pem already exists."
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 3. Build and Push the Native Image'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build --build-arg "PETCLINIC_REF=$PETCLINIC_REF" -t "$NATIVE_IMAGE_NAME" "$DEMO_DIR"
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push "$NATIVE_IMAGE_NAME"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Render the Manifests'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/secret.template.yaml" --values-file "$DEMO_DIR/Values.yaml"  --create-values-file --output "$DEMO_DIR/manifests/secret.yaml"
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/mariadb.template.yaml" --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/mariadb.yaml"
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/petclinic.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/petclinic.yaml"
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "$DEMO_DIR/manifests/scone.template.yaml"  --values-file "$DEMO_DIR/Values.yaml" --create-values-file --output "$DEMO_DIR/manifests/scone.yaml" --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Protect the Image with SCONE'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
(cd "$DEMO_DIR" && scone-td-build from -y manifests/scone.yaml)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Deploy MariaDB and PetClinic'
printf '%s\n' ''
printf '%s\n' 'Deploy the native MariaDB and wait for it:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/secret.yaml" -f "$DEMO_DIR/manifests/mariadb.yaml"
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/petclinic-db -n "$NAMESPACE"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then deploy the confidential PetClinic:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -n "$NAMESPACE" -f "$DEMO_DIR/manifests/manifest.prod.sanitized.yaml"
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/petclinic -n "$NAMESPACE"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Verify the Deployment'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# List the Kubernetes resources in the namespace.
EOF
)"
pe "$(cat <<'EOF'
kubectl get pods -n "$NAMESPACE"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to reach the UI:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl port-forward -n "$NAMESPACE" svc/petclinic 8080:80
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Clean Up'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes namespace.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete namespace "$NAMESPACE"
EOF
)"

printf "%b" "$LILAC"
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
printf '%s\n' 'Then run `./run.sh`. What changes:'
printf '%s\n' ''
printf '%s\n' '- `SCONE_PRODUCTION=1` makes the enclave non-debug. Production enclaves must be signed, so `run.sh` generates an enclave signing key (`identity.pem`, RSA-3072) on first use and passes it via `SCONE_KEY`. That key is the MRSIGNER of your image; keep it private (it is git-ignored).'
printf '%s\n' '- `scone-cas.cf` is SCONE'\''s public CAS. The policy is signed locally (`spol`) and uploaded there.'
printf '%s\n' ''
printf '%s\n' 'Caveats:'
printf '%s\n' ''
printf '%s\n' '- `scone-cas.cf` is itself a debug CAS, so it is accepted with `--only_for_testing-debug`. A fully production trust chain needs a CAS provisioned in production mode.'
printf '%s\n' '- Only PetClinic reaches production here. The optional confidential MariaDB variant (`conf-mariadb/`) uses SCONE product images that are debug-signed, so it cannot run with `SCONE_PRODUCTION=1` (it fails with `Cannot sign production enclave: no key provided`). It runs in debug mode only.'
printf '%s\n' ''
printf "%b" "$RESET"

