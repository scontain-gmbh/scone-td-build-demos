#!/usr/bin/env bash
# Check non-interactive registry bootstrap and Java secret setup without a cluster.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_tplenv="$(command -v tplenv)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fixture="$work/repo"
mkdir -p "$fixture/scripts" "$fixture/java-args-env-file" "$work/bin"
cp "$repo_root/scripts/load-registry-credentials.sh" "$repo_root/scripts/run-all-scripts.sh" "$fixture/scripts/"
cp "$repo_root/java-args-env-file/registry.credentials.md" "$fixture/java-args-env-file/"
python3 - "$repo_root/java-args-env-file/README.md" "$fixture/java-args-env-file/setup-secret.sh" <<'EXTRACT'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text().split('## 6. Add a Docker Registry Secret', 1)[1].split('## 7.', 1)[0]
block = text.split('```bash\n', 1)[1].split('```', 1)[0]
Path(sys.argv[2]).write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + block)
EXTRACT
cat > "$work/startup.env" <<'VALUES'
export REGISTRY=selected.example
export REGISTRY_USER=selected-user
export REGISTRY_TOKEN=selected-token
VALUES
cat > "$fixture/java-args-env-file/Values.yaml" <<'VALUES'
environment:
  NAMESPACE: java-demo
  REGISTRY: ""
  REGISTRY_USER: ""
  REGISTRY_TOKEN: ""
VALUES
cat > "$work/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_CALLS"
case "$*" in
  'get namespace '*) [[ "${MOCK_NAMESPACE_MISSING:-false}" != true ]] ;;
  'create namespace '*) exit 1 ;;
  'create secret generic '*) cat > "$MOCK_SECRET_INPUT"; printf '{"kind":"Secret"}\n' ;;
  'apply '*) cat >/dev/null ;;
  *) exit 99 ;;
esac
MOCK
cat > "$work/bin/tplenv" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_FAIL_CREDENTIALS:-false}" == true ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == --values ]]; then
      printf 'partial credential output\n' > "$2"
      exit 1
    fi
    shift
  done
fi
exec "$MOCK_REAL_TPLENV" "$@"
MOCK
cat > "$work/bin/scone-td-build" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' --unattested-shared-server
MOCK
chmod +x "$work/bin/"* "$fixture/java-args-env-file/setup-secret.sh"
export MOCK_REAL_TPLENV="$real_tplenv" MOCK_CALLS="$work/calls" MOCK_SECRET_INPUT="$work/secret-input"
export PATH="$work/bin:$PATH" SCONE_REGISTRY_ENV_FILE="$work/startup.env"
export NAMESPACE=java-demo IMAGE_PULL_SECRET_NAME=sconeapps SIGNER=test-signer
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
# All suite children must receive the mounted registry credentials.
for name in hello-world configmap web-server network-policy flask-redis flask-redis-netshield go-args-env-file java-args-env-file software-updates pet-clinic image-signing nfs-shared-volume; do
  cat > "$fixture/scripts/$name.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$REGISTRY" == selected.example && "$REGISTRY_USER" == selected-user && "$REGISTRY_TOKEN" == selected-token ]]
[[ "$1" == --non-interactive ]]
printf '%s\n' "${0##*/}" >> "$MOCK_CHILDREN"
MOCK
  chmod +x "$fixture/scripts/$name.sh"
done
export MOCK_CHILDREN="$work/children"
(cd "$fixture" && ./scripts/run-all-scripts.sh > "$work/output" 2>&1)
[[ "$(wc -l < "$MOCK_CHILDREN")" == 12 ]]
printf 'ok - suite runner exports mounted registry credentials to every child\n'
run_java() {
  : > "$MOCK_CALLS"
  (cd "$fixture/java-args-env-file" && "$@" bash ./setup-secret.sh > "$work/output" 2>&1)
}
sha256sum "$fixture/java-args-env-file/Values.yaml" > "$work/values-before"
run_java env
grep -Fq -- 'create secret generic -n java-demo sconeapps --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin --dry-run=client' "$MOCK_CALLS"
grep -Fq '"selected.example":{"username":"selected-user","password":"selected-token"' "$MOCK_SECRET_INPUT"
if grep -Fq selected-token "$MOCK_CALLS"; then
  echo 'FAIL - the registry token is on the kubectl command line' >&2
  exit 1
fi
grep -Fq 'apply -n java-demo -f -' "$MOCK_CALLS"
sha256sum "$fixture/java-args-env-file/Values.yaml" > "$work/values-after"
cmp -s "$work/values-before" "$work/values-after"
[[ -f "$fixture/java-args-env-file/Values.credentials.yaml" ]]
printf 'ok - empty shared Values fields do not mask mounted credentials or collect secrets\n'
cat > "$fixture/java-args-env-file/Values.credentials.yaml.next" <<'VALUES'
environment:
  REGISTRY: saved.example
  REGISTRY_USER: saved-user
  REGISTRY_TOKEN: saved-token
VALUES
mv "$fixture/java-args-env-file/Values.credentials.yaml.next" "$fixture/java-args-env-file/Values.credentials.yaml"
run_java env
grep -Fq '"saved.example":{"username":"saved-user","password":"saved-token"' "$MOCK_SECRET_INPUT"
printf 'ok - ignored local credentials retain tplenv saved-value precedence\n'
sha256sum "$fixture/java-args-env-file/Values.credentials.yaml" > "$work/credentials-before"
if run_java env MOCK_FAIL_CREDENTIALS=true; then
  echo 'FAIL - partial credential write reported success' >&2
  exit 1
fi
sha256sum "$fixture/java-args-env-file/Values.credentials.yaml" > "$work/credentials-after"
cmp -s "$work/credentials-before" "$work/credentials-after"
if compgen -G "$fixture/java-args-env-file/Values.credentials.yaml.*" >/dev/null; then
  echo 'FAIL - a temporary credentials file was left behind' >&2
  exit 1
fi
if grep -Fq 'create secret' "$MOCK_CALLS"; then
  echo 'FAIL - invalid setup still attempted secret creation' >&2
  exit 1
fi
printf 'ok - failed credential render preserves existing values and creates no secret\n'
if run_java env MOCK_NAMESPACE_MISSING=true; then
  echo 'FAIL - unavailable namespace reported success' >&2
  exit 1
fi
if grep -Fq 'create secret' "$MOCK_CALLS"; then
  echo 'FAIL - invalid setup still attempted secret creation' >&2
  exit 1
fi
printf 'ok - missing namespace stops setup before creating a secret\n'
rm "$fixture/java-args-env-file/Values.credentials.yaml"
cat > "$work/empty.env" <<'VALUES'
export REGISTRY=""
export REGISTRY_USER=""
export REGISTRY_TOKEN=""
VALUES
if run_java env SCONE_REGISTRY_ENV_FILE="$work/empty.env"; then
  echo 'FAIL - missing registry credentials reported success' >&2
  exit 1
fi
if grep -Fq 'create secret' "$MOCK_CALLS"; then
  echo 'FAIL - invalid setup still attempted secret creation' >&2
  exit 1
fi
[[ ! -f "$fixture/java-args-env-file/Values.credentials.yaml" ]]
printf 'ok - empty credentials fail clearly without saving invalid values or creating a secret\n'
