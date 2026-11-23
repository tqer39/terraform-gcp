output "services" {
  description = "有効にした API のサービス名。"
  value       = toset([for service in google_project_service.this : service.service])
}
