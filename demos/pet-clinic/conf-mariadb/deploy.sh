#!/usr/bin/env bash
# Deploy a confidential MariaDB (SCONE `mariadb-spr` Helm chart) adapted to a
# SCONE 6.x cluster. This is an optional variant of the pet-clinic demo: it
# replaces the native MariaDB with a confidential (SGX) MariaDB that PetClinic
# talks to through a confidential MaxScale over TLS.
#
# All configuration comes from ../Values.yaml via tplenv (CAS_NAME,
# CAS_NAMESPACE, NAMESPACE, MARIADB_SCONE_IMAGE, MAXME_IMAGE). Edit Values.yaml,
# then run this script. GITHUB_TOKEN (for the sconeappsee helm repo) comes from
# the environment, e.g. `source ~/.env`.
#
# Differences from the upstream maria.sh this is based on:
#   * uses the local `scone` CLI (matches the cluster version) instead of the
#     dockerised sconecli:5.9.0,
#   * uses SIGNED policies (spol) instead of encrypted policies (epol), so it
#     also works against the public CAS (scone-cas.cf) where epol is not
#     supported yet.
#
# IMPORTANT: the SCONE curated MariaDB/MaxScale images are DEBUG-signed. They
# run in SGX debug mode only; SCONE_PRODUCTION=1 fails with "Cannot sign
# production enclave: no key provided". See README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DEMO_DIR="$SCRIPT_DIR/../../pet-clinic/"


# Seed Values.yaml from the template on first run only.
[ -f "$DEMO_DIR/Values.yaml" ] || cp "$DEMO_DIR/values.template.yaml" "$DEMO_DIR/Values.yaml"

# Load configuration from Values.yaml via tplenv (no flags).
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
eval "$(tplenv --file "$DEMO_DIR/../environment-variables.md" --values-file "$DEMO_DIR/Values.yaml" --eval-export-values --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)"

: "${GITHUB_TOKEN:?set GITHUB_TOKEN in the environment (needed for the sconeappsee helm repo)}"

if ! helm plugin list | grep -q "git"; then
  echo "==> Installing helm-git plugin..."
  helm plugin install https://github.com/aslafy-z/helm-git
fi

kubectl create namespace $NAMESPACE || true

echo "==> helm install mariadb-spr (from git repo)"
HELM_GIT_URL="git+https://${GITHUB_TOKEN}@github.com/scontain/mariadb-code.git@helm-chart?ref=main"

CAS_NAME_ONLY="${SCONE_CAS_ADDR%.*}"; 
CAS_NAMESPACE_ONLY="${SCONE_CAS_ADDR##*.}"
echo "==> Attest CAS ${SCONE_CAS_ADDR} (accepted as a debug CAS for testing)"
ATTEST=(scone cas attest "$SCONE_CAS_ADDR" --only_for_testing-debug --only_for_testing-trust-any
        --only_for_testing-ignore-signer --accept-group-out-of-date
        --accept-sw-hardening-needed --accept-configuration-needed)
if kubectl get cas "$CAS_NAME_ONLY" -n "$CAS_NAMESPACE_ONLY" >/dev/null 2>&1; then
  # In-cluster CAS: attest offline from the CAS resource's DCAP report.
  RPT=$(mktemp)
  NONCE=$(kubectl get cas "$CAS_NAME_ONLY" -n "$CAS_NAMESPACE_ONLY" -o json \
    | python3 -c "import sys,json;d=json.load(sys.stdin)['status'];open('$RPT','w').write(d['dcapReport']);print(d['nonce'])")
  "${ATTEST[@]}" --nonce "$NONCE" --offline-report "$RPT" >/dev/null
  rm -f "$RPT"
else
  "${ATTEST[@]}" >/dev/null   # e.g. scone-cas.cf: attest online
fi

scone cas set-default "$SCONE_CAS_ADDR" >/dev/null

echo "==> Sign + create the 6 sessions (spol) on ${SCONE_CAS_ADDR}"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
declare -A rn
for k in certificates maxscale primary replica backup dba-policy; do
  rn[$k]="${k%-policy}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')"
done
for tmpl in "$DEMO_DIR/conf-mariadb/security-policies/"*.template.yaml; do
  key=$(basename "$tmpl" .template.yaml); name="${rn[$key]}"
  cp "$tmpl" "$WORK/$name.yaml"
  for k in "${!rn[@]}"; do sed -i "s/{{$k}}/${rn[$k]}/g" "$WORK/$name.yaml"; done
  scone session sign "$WORK/$name.yaml" > "$WORK/$name.json"
  h=$(scone session create "$WORK/$name.json")
  echo "     ${name} -> ${h:0:16}"
done

echo "==> helm install mariadb (debug mode; images from Values.yaml)"

helm repo remove mariadb-spr  > /dev/null || true

helm repo add mariadb-spr "$HELM_GIT_URL"

helm install mariadb mariadb-spr/mariadb-spr \
  -n "$NAMESPACE" \
  --set image="$MARIADB_SCONE_IMAGE" \
  --set maxscale.metrics.image="$MAXME_IMAGE" \
  --set scone.attestation.cas="$SCONE_CAS_ADDR" \
  --set scone.attestation.maxscaleConfigID="${rn[maxscale]}/maxscale" \
  --set scone.attestation.maxmeConfigID="${rn[maxscale]}/maxme" \
  --set scone.attestation.primaryBaseConfigID="${rn[primary]}" \
  --set scone.attestation.replicaBaseConfigID="${rn[replica]}" \
  --set scone.attestation.backupBaseConfigID="${rn[backup]}" \
  --set maxscale.enabled=true --set maxscale.metrics.enabled=false \
  --set replica.replicas=1 \
  --set primary.metrics.enabled=false --set replica.metrics.enabled=false --set backup.enabled=false \
  --set primary.persistence.enabled=true --set primary.persistence.storageClass=local-path --set primary.persistence.size=8Gi \
  --set replica.persistence.enabled=true --set replica.persistence.storageClass=local-path --set replica.persistence.size=8Gi

cat <<EOF

==> Done. Confidential MariaDB is coming up in namespace ${NAMESPACE}.
    Watch it:   kubectl -n ${NAMESPACE} get pods | grep mariadb-spr
    Endpoint:   maxscale:3306  (TLS, sslMode=REQUIRED, user root / password 098098)

    To point the confidential PetClinic at it, set in manifests/petclinic.template.yaml:
      SPRING_DATASOURCE_URL: jdbc:mysql://maxscale:3306/\${DB_NAME}?sslMode=REQUIRED
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: "098098"
    (root@% has ALL PRIVILEGES; the petclinic database is created on first use.)
EOF
