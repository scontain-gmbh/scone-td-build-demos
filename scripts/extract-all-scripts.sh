#!/usr/bin/env bash

set -euo pipefail

# Array of input/output file pairs
files=(
  "hello-world/README.md scripts/hello-world.sh"
  "configmap/README.md scripts/configmap.sh"
)

# Loop over the file pairs
for pair in "${files[@]}"; do
  ./scripts/extract-bash.sh $pair
done
