#!/usr/bin/env bash
# Check non-interactive registry bootstrap and Java secret setup without a cluster.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fixture="$work/repo"
mkdir -p "$fixture/scripts/demos" "$fixture/demos/java-args-env-file" "$work/bin"
cp "$repo_root/scripts/load-registry-credentials.sh" "$repo_root/scripts/run-all-demos.sh" "$fixture/scripts/"
python3 - "$repo_root/demos/java-args-env-file/README.md" "$fixture/demos/java-args-env-file/setup-secret.sh" <<'EXTRACT'
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
cat > "$work/bin/scone-td-build" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' --unattested-shared-server
MOCK
chmod +x "$work/bin/"* "$fixture/demos/java-args-env-file/setup-secret.sh"
export MOCK_CALLS="$work/calls" MOCK_SECRET_INPUT="$work/secret-input"
export PATH="$work/bin:$PATH" SCONE_REGISTRY_ENV_FILE="$work/startup.env"
export NAMESPACE=java-demo IMAGE_PULL_SECRET_NAME=sconeapps SIGNER=test-signer
export DEMO_DIR="$fixture/demos/java-args-env-file"
# All suite children must receive the mounted registry credentials.
for name in hello-world configmap web-server network-policy flask-redis flask-redis-netshield go-args-env-file java-args-env-file software-updates pet-clinic image-signing governance; do
  cat > "$fixture/scripts/demos/$name.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$REGISTRY" == selected.example && "$REGISTRY_USER" == selected-user && "$REGISTRY_TOKEN" == selected-token ]]
[[ "$1" == --non-interactive ]]
printf '%s\n' "${0##*/}" >> "$MOCK_CHILDREN"
MOCK
  chmod +x "$fixture/scripts/demos/$name.sh"
done
export MOCK_CHILDREN="$work/children"
(cd "$fixture" && ./scripts/run-all-demos.sh > "$work/output" 2>&1)
[[ "$(wc -l < "$MOCK_CHILDREN")" == 12 ]]
printf 'ok - suite runner exports mounted registry credentials to every child\n'
run_java() {
  : > "$MOCK_CALLS"
  (cd "$fixture" && "$@" bash "$DEMO_DIR/setup-secret.sh" > "$work/output" 2>&1)
}
run_java env
grep -Fq -- 'create secret generic -n java-demo sconeapps --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin --dry-run=client' "$MOCK_CALLS"
grep -Fq '"selected.example":{"username":"selected-user","password":"selected-token"' "$MOCK_SECRET_INPUT"
if grep -Fq selected-token "$MOCK_CALLS"; then
  echo 'FAIL - the registry token is on the kubectl command line' >&2
  exit 1
fi
printf 'ok - mounted credentials reach the secret on stdin, not on the command line\n'
if run_java env MOCK_NAMESPACE_MISSING=true; then
  echo 'FAIL - unavailable namespace reported success' >&2
  exit 1
fi
if grep -Fq 'create secret' "$MOCK_CALLS"; then
  echo 'FAIL - invalid setup still attempted secret creation' >&2
  exit 1
fi
printf 'ok - missing namespace stops setup before creating a secret\n'
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
printf 'ok - empty credentials fail clearly without creating a secret\n'
