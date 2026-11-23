variable "project_id" {
  description = "WIF とサービスアカウントを作成するプロジェクト ID。"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "プロジェクト ID は 6〜30 文字の英小文字・数字・ハイフンで指定してください。"
  }
}

variable "github_repository" {
  description = "認証を許可する GitHub リポジトリの所有者/リポジトリ名。"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "GitHub リポジトリは owner/repository 形式で指定してください。"
  }
}

variable "pool_id" {
  description = "Workload Identity Pool の ID。"
  type        = string
  default     = "github-actions"
  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.pool_id)) && !startswith(var.pool_id, "gcp-")
    error_message = "pool_id は 4〜32 文字の英小文字・数字・ハイフンとし、gcp- で始めないでください。"
  }
}

variable "provider_id" {
  description = "GitHub OIDC provider の ID。"
  type        = string
  default     = "github"
  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.provider_id)) && !startswith(var.provider_id, "gcp-")
    error_message = "provider_id は 4〜32 文字の英小文字・数字・ハイフンとし、gcp- で始めないでください。"
  }
}

variable "service_account_id" {
  description = "Terraform 実行用サービスアカウントの ID。"
  type        = string
  default     = "terraform-github"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.service_account_id))
    error_message = "サービスアカウント ID は 6〜30 文字で、英小文字で始まり英小文字か数字で終わる形式にしてください。"
  }
}

variable "project_roles" {
  description = "Terraform 実行用サービスアカウントに付与するプロジェクトロール。"
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for role in var.project_roles : can(regex("^roles/[A-Za-z0-9_.]+$", role))])
    error_message = "ロールは roles/service.role 形式の事前定義ロールを指定してください。"
  }
}
