#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
config=terraform/envs/sandbox/base/sandbox.json

if [[ ${1:-} == --help ]]; then
  echo "使い方: $0 [PROJECT_ID] [BILLING_ACCOUNT_ID]"
  echo "環境変数: PROJECT_ID, BILLING_ACCOUNT_ID, STATE_BUCKET, REGION"
  exit 0
fi
if [[ $# -gt 2 ]]; then
  echo "引数は PROJECT_ID と BILLING_ACCOUNT_ID の 2 個までです。" >&2
  exit 1
fi
command -v gcloud >/dev/null
command -v jq >/dev/null

project_id=${1:-${PROJECT_ID:-$(jq -er '.project_id' "$config")}}
billing_account_id=${2:-${BILLING_ACCOUNT_ID:-}}
state_bucket=${STATE_BUCKET:-$(jq -er '.state_bucket' "$config")}
region=${REGION:-$(jq -er '.region' "$config")}

if [[ ! $project_id =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ||
      ! $billing_account_id =~ ^[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}$ ]]; then
  echo "有効な PROJECT_ID と BILLING_ACCOUNT_ID を指定してください。" >&2
  exit 1
fi
if [[ ! $state_bucket =~ ^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$ ||
      ! $region =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
  echo "STATE_BUCKET または REGION の形式が不正です。" >&2
  exit 1
fi

# 認証失敗や権限不足を「未作成」と誤認しないよう、一覧取得の失敗はそのまま終了する。
existing_project=$(gcloud projects list --filter="projectId=$project_id" --format='value(projectId)')
if [[ $existing_project != "$project_id" ]]; then
  gcloud projects create "$project_id" --quiet
fi

gcloud billing projects link "$project_id" --billing-account="$billing_account_id" --quiet
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  serviceusage.googleapis.com \
  storage.googleapis.com \
  sts.googleapis.com \
  --project="$project_id" --quiet

# 他プロジェクトの同名バケットには設定変更を行わない。
existing_bucket=$(gcloud storage buckets list --project="$project_id" \
  --filter="name=$state_bucket" --format='value(name)')
if [[ $existing_bucket != "$state_bucket" ]]; then
  gcloud storage buckets create "gs://$state_bucket" \
    --project="$project_id" --location="$region" \
    --uniform-bucket-level-access --public-access-prevention --quiet
fi
gcloud storage buckets update "gs://$state_bucket" --project="$project_id" \
  --versioning --uniform-bucket-level-access --public-access-prevention --quiet

echo "準備完了: project=$project_id bucket=$state_bucket"
echo "Terraform 実行前に sandbox.json と指定値が一致していることを確認してください。"
