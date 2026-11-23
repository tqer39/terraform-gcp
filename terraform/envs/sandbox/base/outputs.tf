output "workload_identity_provider" {
  description = "GitHub repository variable GCP_WORKLOAD_IDENTITY_PROVIDER の値。"
  value       = module.github_oidc.workload_identity_provider
}

output "service_account_email" {
  description = "GitHub repository variable GCP_SERVICE_ACCOUNT の値。"
  value       = module.github_oidc.service_account_email
}
