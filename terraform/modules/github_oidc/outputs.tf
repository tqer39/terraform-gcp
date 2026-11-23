output "workload_identity_provider" {
  description = "GCP_WORKLOAD_IDENTITY_PROVIDER に設定する完全な provider 名。"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "GCP_SERVICE_ACCOUNT に設定するサービスアカウントメール。"
  value       = google_service_account.terraform.email
}
