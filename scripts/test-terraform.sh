#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for directory in terraform/modules/*; do
  terraform -chdir="$directory" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$directory" test -no-color
done
