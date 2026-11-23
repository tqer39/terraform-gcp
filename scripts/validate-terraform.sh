#!/usr/bin/env bash
# CI と同じ lockfile を使い、GCP 認証なしで全スタックを検証する。
set -euo pipefail
cd "$(dirname "$0")/.."
for config in terraform/envs/*/*/terraform.tf; do
  directory=${config%/terraform.tf}
  echo "検証: $directory"
  terraform -chdir="$directory" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$directory" validate -no-color
done
