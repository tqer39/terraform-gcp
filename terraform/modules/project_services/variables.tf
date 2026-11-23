variable "project_id" {
  description = "API を有効にする GCP プロジェクト ID。"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "プロジェクト ID は 6〜30 文字の英小文字・数字・ハイフンで指定してください。"
  }
}

variable "services" {
  description = "有効にする API のサービス名。"
  type        = set(string)
  validation {
    condition     = alltrue([for service in var.services : can(regex("^[a-z][a-z0-9.-]*\\.googleapis\\.com$", service))])
    error_message = "API 名は service.googleapis.com の形式で指定してください。"
  }
}
