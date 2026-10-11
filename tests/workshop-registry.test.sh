#!/usr/bin/env bash
# shellcheck disable=SC2034  # out and rc are read inside the eval-ed check expressions
# Checks the workshop registry helpers without a cluster:
#   tests/workshop-registry.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

# 1. prepull-base-images.sh --list works with the oldest Bash we support (macOS ships 3.2).
for shell in /bin/bash bash; do
  out="$("${shell}" "${repo_root}/scripts/prepull-base-images.sh" --list 2>&1)" && rc=0 || rc=$?
  check "prepull --list runs with $("${shell}" -c 'echo bash ${BASH_VERSION}')" '[[ $rc == 0 && $out == *python:* ]]'
done

# 2 + 3. After use-registry.sh localhost:30500, the image-signing commands configure
# sigstore attachments and cosign for the registry that receives the signed image.
cp -R "${repo_root}" "${work}/repo"
HOME="${work}/home" XDG_CONFIG_HOME="${work}/home/.config" \
  "${work}/repo/scripts/use-registry.sh" localhost:30500 >/dev/null
dest="$(awk -F': ' '/^  DESTINATION_IMAGE_NAME:/{print $2}' "${work}/repo/image-signing/Values.yaml")"
check "use-registry rewrites the image-signing destination" '[[ $dest == localhost:30500/* ]]'

# Run the two documented snippets from image-signing/README.md with a mocked cosign.
awk '/^SIGNING_REGISTRY=/{p=1} p{print} p&&/^EOF$/{exit}' "${work}/repo/image-signing/README.md" > "${work}/signing.sh"
awk '/^COSIGN_REGISTRY_FLAGS=""/{p=1} p{print} p&&/^cosign verify/{exit}' "${work}/repo/image-signing/README.md" > "${work}/verify.sh"
mkdir -p "${work}/bin" && printf '#!/bin/sh\necho "$@" > "%s/cosign.args"\n' "${work}" > "${work}/bin/cosign" && chmod +x "${work}/bin/cosign"
HOME="${work}/home" DESTINATION_IMAGE_NAME="${dest}" PATH="${work}/bin:${PATH}" bash -c \
  "set -euo pipefail; source '${work}/signing.sh'; source '${work}/verify.sh'"
check "sigstore attachments are configured for localhost:30500" \
  'grep -q "localhost:30500:" "${work}/home/.config/containers/registries.d/image-signing-demo.yaml"'
check "cosign is told to use plain HTTP for localhost:30500" 'grep -q -- "--allow-http-registry" "${work}/cosign.args"'
check "skopeo marks localhost:30500 insecure" \
  'grep -q "location = \"localhost:30500\"" "${work}/home/.config/containers/registries.conf"'

HOME="${work}/home2" DESTINATION_IMAGE_NAME="ghcr.io/me/image-signing:scone" PATH="${work}/bin:${PATH}" bash -c \
  "set -euo pipefail; source '${work}/signing.sh'; source '${work}/verify.sh'"
check "cosign keeps HTTPS for other registries" '! grep -q -- "--allow-http-registry" "${work}/cosign.args"'

# 4. Generated scripts parse with every Bash we have (docs/*.sh run the screencasts).
for shell in /bin/bash bash; do
  bad=""
  for f in "${repo_root}"/scripts/*.sh "${repo_root}"/docs/*.sh; do
    "${shell}" -n "$f" 2>/dev/null || bad="${bad} $(basename "$f")"
  done
  check "generated scripts parse with $("${shell}" -c 'echo bash ${BASH_VERSION}')" '[[ -z $bad ]]'
done

# 5. ensure-local-registry.sh reuses a registry, creates one on a free port, and
# refuses an unrelated service on the NodePort. Mocked kubectl.
cat > "${work}/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$KUBECTL_LOG"
case "$*" in
  "get svc -A -o jsonpath="*) printf '%b' "$MOCK_SVCS" ;;
  "get --raw "*) [[ "$MOCK_IS_REGISTRY" == 1 ]] ;;
  "apply -f "*) echo applied ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "${work}/bin/kubectl"
ensure() {
  : > "${work}/kubectl.log"
  env PATH="${work}/bin:${PATH}" KUBECTL_LOG="${work}/kubectl.log" MOCK_SVCS="$1" MOCK_IS_REGISTRY="$2" \
    "${repo_root}/scripts/ensure-local-registry.sh" >/dev/null 2>&1 && rc=0 || rc=$?
}
ensure '' 0
check "free NodePort: the workshop registry is created" '[[ $rc == 0 ]] && grep -q "^apply -f" "${work}/kubectl.log"'
ensure '30500 30500 |reg-ns/registry-registry\n31000 80 |web/frontend\n' 1
check "existing registry on the NodePort is reused" \
  '[[ $rc == 0 ]] && grep -q "proxy/v2/" "${work}/kubectl.log" && ! grep -q "^apply" "${work}/kubectl.log"'
ensure '30500 80 |web/frontend\n' 0
check "unrelated service on the NodePort stops the setup" '[[ $rc != 0 ]] && ! grep -q "^apply" "${work}/kubectl.log"'

exit "${failures}"
