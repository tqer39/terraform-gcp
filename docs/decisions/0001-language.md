# 開発言語の選定

## 要件

個人用 GCP sandbox の API と GitHub Actions 向け WIF を宣言的に管理します。
認証情報なしで構文・依存関係・認証条件を検証できることを重視します。

## 候補

Terraform（HCL）、Pulumi（TypeScript または Go で記述）、gcloud のみのシェルスクリプトを比較しました。

## 選定理由

terraform-aws と同じレイアウト、plan/apply の運用、mise による検証を再利用できる Terraform（HCL）を採用します。
汎用言語の実行環境とビルドを持ち込まないため、Pulumi は採用しません。
Node.js（JavaScript）は Markdown lint の実行にだけ使い、インフラの定義には使いません。
GCS backend の前提となるプロジェクト・課金・バケットの初期化だけ Bash と gcloud で補います。
検証範囲は fmt、tflint、actionlint、shellcheck、terraform validate と mock provider による terraform test です。
実 API の権限、課金、OIDC トークン交換、リソースの作成は人間による初回適用時に確認します。
