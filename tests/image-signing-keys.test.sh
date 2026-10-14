#!/usr/bin/env bash
# Check that the image-signing key step can run again in the same checkout.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/image-signing/config" "$work/bin"
python3 - "$repo_root/image-signing/README.md" "$work/image-signing/generate-keys.sh" <<'EXTRACT'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text().split('## 4. Generate Signing Keys', 1)[1].split('## 5.', 1)[0]
block = text.split('```bash\n', 1)[1].split('```', 1)[0]
Path(sys.argv[2]).write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + block)
EXTRACT
# Like skopeo, refuse to overwrite either file of an existing key pair.
cat > "$work/bin/skopeo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == generate-sigstore-key ]]
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-prefix) prefix="$2"; shift 2 ;;
    *) shift ;;
  esac
done
for file in "$prefix.pub" "$prefix.private"; do
  if [[ -e "$file" ]]; then
    printf 'Refusing to overwrite existing "%s"\n' "$file" >&2
    exit 1
  fi
done
printf 'key %s\n' "$RANDOM" > "$prefix.private"
printf 'key %s\n' "$RANDOM" > "$prefix.pub"
MOCK
chmod +x "$work/bin/skopeo" "$work/image-signing/generate-keys.sh"
export PATH="$work/bin:$PATH"
run_step() {
  (cd "$work/image-signing" && bash ./generate-keys.sh > "$work/output" 2>&1)
}
run_step
if ! run_step; then
  echo 'FAIL - generating the signing keys again in the same checkout failed:' >&2
  cat "$work/output" >&2
  exit 1
fi
[[ -s "$work/image-signing/config/image-signing-key.private" && -s "$work/image-signing/config/image-signing-key.pub" ]]
printf 'ok - signing keys can be generated again after an earlier run\n'
