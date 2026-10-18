#!/bin/bash
# Temporary SDV-026 harness: compile every generated input root with
# `scone-sptd-build build` (offline sanitizer) and verify each published bundle.
# Usage: run_sptd_build.sh BIN LABEL INPUTS_DIR OUT_DIR VARIANT...
set -u
BIN=$1 LABEL=$2 IN=$3 OUT=$4; shift 4
mkdir -p "$OUT"
"$BIN" --version
for variant in "$@"; do
  for root in "$IN/$variant"/*/*/; do
    root=${root%/}; wl=$(basename "$root"); case=$(basename "$(dirname "$root")")
    gen="$LABEL-$variant-$case-$wl"
    log="$OUT/$gen.log"
    "$BIN" build --input-root "$root" --spec plan.json --output "$OUT" \
      --generation "$gen" --staging "$gen-stage" > "$OUT/$gen.receipt.json" 2> "$log"
    rc=$?
    if [ $rc -eq 0 ]; then
      "$BIN" verify --bundle-root "$OUT" --generation "$gen" --receipt "$gen.receipt.json" --exact >> "$log" 2>&1
      vrc=$?
      [ $vrc -eq 0 ] && res=PASS || res="FAIL(verify rc=$vrc)"
    else
      res="FAIL(build rc=$rc)"; rm -f "$OUT/$gen.receipt.json"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$LABEL" "$variant" "$case" "$wl" "$res: $(tr '\n' ' ' < "$log")"
  done
done
