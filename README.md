# terraform-gcp

個人用 GCP sandbox の API と GitHub Actions 向け Workload Identity Federation（WIF）を Terraform で管理します。
サービスアカウントキーは作成しません。VPC やアプリケーションのリソースは含めません。

## 構成

```text
terraform/
  envs/sandbox/base/        sandbox のスタックと GCS backend
    sandbox.json           プロジェクト・リージョン・state バケット・リポジトリの設定
  modules/project_services/ API の有効化（破棄時は無効化しない）
  modules/github_oidc/      WIF・Terraform 用 SA・IAM
scripts/bootstrap-gcp.sh    人間の認証で行う初期化
scripts/validate-terraform.sh 全スタックの認証不要検証
scripts/test-terraform.sh   モジュールの mock テスト
.github/workflows/terraform.yml PR の検証・plan、main push の apply
mise.toml                  ツールの固定と検証タスク（dev-standards の生成物）
.standards/                dev-standards の正本（mise.project.toml、gitignore.local など）
docs/decisions/0001-language.md 開発言語の選定理由
```

設定は [sandbox.json](terraform/envs/sandbox/base/sandbox.json) の 1 か所で変更します。
既定値は次のとおりです。

| 項目 | 既定値 |
| --- | --- |
| プロジェクト | `sandbox-tqer39` |
| リージョン | `asia-northeast1` |
| バケット | `sandbox-tqer39-tfstate` |
| リポジトリ | `tqer39/terraform-gcp` |

backend は変数や locals を参照できないため、`terraform init` に同ファイルのバケット名を渡します。
初回適用後にバケット名を変更する場合は state の移行が必要です。

## 共通開発ルール

[dev-standards](https://github.com/tqer39/dev-standards) の `mise-project` プロファイルを適用しています。
`mise.toml`、`.gitignore`、`.editorconfig`、`AGENTS.md` などは生成物です。
変更するときは `.standards/` の正本を編集し、`mise run standards:plan` で計画を作って適用します。

## ローカル検証

mise を事前に導入し、`mise.toml` の内容を確認してから実行します。
ツールと provider の初回取得にはインターネット接続が必要です。GCP 認証は不要です。

```bash
mise trust
mise run bootstrap
mise run check
```

`check` は lint、整形確認、テスト、build をまとめて実行します。整形する場合は `mise run format` を使います。
`bootstrap` は npm 依存（markdownlint、textlint、cspell）と tflint を準備し、再実行できます。
`check` と `standards:*` のタスクは `.standards/cache/dev-standards` を使います。
この CLI は Git の管理対象外です。新しい checkout では、lock と同じ版の dev-standards で
`dev-standards sync` を先に実行して配置します。lint、整形確認、テスト、build は CLI なしでも個別に実行できます。
`test` は各モジュールを初期化して `mock_provider "google"` でテストします。
`build` は全スタックを `init -backend=false` で初期化して `validate` します。
いずれも実 GCP リソースの plan/apply を行いません。
mock テストは認証条件と IAM member の構成を検証し、実 API の動作や権限の充足までは保証しません。

provider は Google の 8 系に制約し、各モジュールとスタックの `.terraform.lock.hcl` を管理します。
lockfile には CI（linux_amd64）とローカル（darwin_arm64）の両方のハッシュを含めます。
更新時は各ディレクトリで次を実行し、差分とテストを確認します。

```bash
terraform init -backend=false -upgrade
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```

`.terraform/`、state、保存した plan、認証情報はコミットしないでください。

## 人間が行う作業

1. Google Cloud CLI を導入し、ログインします。
   課金が有効なアカウント、プロジェクト作成権限、課金アカウントの利用権限が必要です。
   既存プロジェクトでは API・IAM・SA・WIF・バケットを管理できる権限も確認します。

   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. `sandbox.json` を編集してプロジェクト ID と全世界で一意なバケット名を決めます。
   課金アカウントを確認し、その ID を指定します。ID をリポジトリに保存する必要はありません。

   ```bash
   gcloud billing accounts list
   export BILLING_ACCOUNT_ID='実際の課金アカウントID'
   ```

3. 初期化スクリプトを実行します。ここからは実際の GCP リソースと課金設定を変更します。
   jq は `mise install` で準備します。プロジェクトが既存なら作成を省略します。
   課金リンク、API 有効化、バケット作成、安全設定は再実行できます。
   state バケットとプロジェクトは Terraform の管理対象に含めず、bootstrap で維持します。

   ```bash
   mise exec -- bash scripts/bootstrap-gcp.sh
   ```

   引数 `PROJECT_ID BILLING_ACCOUNT_ID`、または同名の環境変数でも指定できます。
   `STATE_BUCKET` と `REGION` も環境変数で指定できますが、必ず `sandbox.json` と一致させます。
   一覧の取得に失敗した場合は未作成と見なさず終了します。
   バケットには versioning、uniform bucket-level access、public access prevention を設定します。

4. 人間の ADC 認証を使って Terraform を初めて適用します。
   WIF はまだ存在しないため、最初の適用を GitHub Actions からは実行できません。

   ```bash
   eval "$(mise env)"
   mise exec -- gcloud auth application-default set-quota-project "$(jq -er .project_id terraform/envs/sandbox/base/sandbox.json)"
   mise exec -- terraform -chdir=terraform/envs/sandbox/base init \
     -backend-config="bucket=$(jq -er .state_bucket terraform/envs/sandbox/base/sandbox.json)"
   mise exec -- terraform -chdir=terraform/envs/sandbox/base plan -out=tfplan
   mise exec -- terraform -chdir=terraform/envs/sandbox/base apply tfplan
   mise exec -- terraform -chdir=terraform/envs/sandbox/base output
   ```

   IAM の伝播に数分かかる場合があります。初回適用後に認証できない場合は伝播を待って確認します。

5. GitHub の Settings → Secrets and variables → Actions → Variables で次を登録します。

   | Repository variable | Terraform output |
   | --- | --- |
   | `GCP_WORKLOAD_IDENTITY_PROVIDER` | `workload_identity_provider` |
   | `GCP_SERVICE_ACCOUNT` | `service_account_email` |

   両方が設定されるまでは plan/apply ジョブをスキップし、認証不要の検証だけを実行します。
   設定後は同じリポジトリ内の PR で plan、検証に成功した main への push で apply を実行します。
   fork の PR は認証付き plan をスキップします。

## 認証と権限

WIF の issuer は `https://token.actions.githubusercontent.com` です。
条件は `assertion.repository_owner` と `assertion.repository` の両方を照合します。
`roles/iam.workloadIdentityUser` は対象リポジトリの principalSet にだけ付与します。
所有者名やリポジトリ名を変更した場合は、人間の認証で条件と GitHub variables を更新します。

Terraform 用 SA には、API 有効化、WIF 管理、SA 管理、プロジェクト IAM 管理、
state 読み書きのためのロールを付与します。`roles/storage.objectAdmin` はプロジェクト全体に適用されます。
プロジェクト IAM 管理は権限の追加も可能な強い権限です。
同じリポジトリ内の PR でも plan はこの SA を利用するため、コードとワークフローを信頼できる共同作業者に限定します。
main の保護と必須検証を GitHub で設定し、適用対象をレビューしてください。

Action の固定 SHA は GitHub API の最新リリースと tag の参照先で確認しています。
検証ジョブだけ mise のキャッシュを利用し、GCP に認証するジョブでは復元しません。

参考: [Terraform の backend 設定](https://developer.hashicorp.com/terraform/language/backend)、
[Google provider の WIF 設定](https://github.com/hashicorp/terraform-provider-google/blob/main/website/docs/r/iam_workload_identity_pool_provider.html.markdown)、
[バケットの安全設定](https://docs.cloud.google.com/sdk/gcloud/reference/storage/buckets/update)。
