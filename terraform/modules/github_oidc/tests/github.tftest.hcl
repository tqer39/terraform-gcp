mock_provider "google" {
  override_during = plan
  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/github-actions"
    }
  }
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/sandbox-example/serviceAccounts/terraform-github@sandbox-example.iam.gserviceaccount.com"
      email = "terraform-github@sandbox-example.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id        = "sandbox-example"
  github_repository = "example-owner/example-repo"
  project_roles     = ["roles/iam.workloadIdentityPoolAdmin"]
}

run "restrict_github_identity" {
  command = plan

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository_owner == 'example-owner' && assertion.repository == 'example-owner/example-repo'"
    error_message = "所有者と対象リポジトリの両方を制限してください。"
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.github.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "GitHub Actions の issuer に限定してください。"
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_mapping["attribute.repository"] == "assertion.repository" && google_iam_workload_identity_pool_provider.github.attribute_mapping["google.subject"] == "assertion.sub"
    error_message = "バインディングに使用するリポジトリと subject のマッピングを維持してください。"
  }
  assert {
    condition     = google_service_account_iam_member.github.member == "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/attribute.repository/example-owner/example-repo"
    error_message = "プロジェクト番号を含む pool 名と対象リポジトリを principalSet に指定してください。"
  }
  assert {
    condition     = google_service_account_iam_member.github.role == "roles/iam.workloadIdentityUser" && google_service_account_iam_member.github.service_account_id == "projects/sandbox-example/serviceAccounts/terraform-github@sandbox-example.iam.gserviceaccount.com"
    error_message = "Terraform 用サービスアカウントへの偽装だけを許可してください。"
  }
  assert {
    condition     = length(google_project_iam_member.terraform) == 1 && google_project_iam_member.terraform["roles/iam.workloadIdentityPoolAdmin"].member == "serviceAccount:terraform-github@sandbox-example.iam.gserviceaccount.com"
    error_message = "指定ロールを Terraform 用サービスアカウントだけに付与してください。"
  }
}

run "different_repository" {
  command = plan
  variables {
    github_repository = "another-owner/another-repo"
    project_roles     = []
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository_owner == 'another-owner' && assertion.repository == 'another-owner/another-repo'" && endswith(google_service_account_iam_member.github.member, "/attribute.repository/another-owner/another-repo")
    error_message = "リポジトリ変更時は条件とバインディングの両方を更新してください。"
  }
  assert {
    condition     = length(google_project_iam_member.terraform) == 0
    error_message = "指定していないロールを付与しないでください。"
  }
}

run "reject_condition_injection" {
  command = plan
  variables {
    github_repository = "owner/repo' || true"
  }
  expect_failures = [var.github_repository]
}

run "reject_reserved_pool_id" {
  command = plan
  variables {
    pool_id = "gcp-reserved"
  }
  expect_failures = [var.pool_id]
}
