mock_provider "google" {}

variables {
  project_id = "sandbox-example"
  services   = ["iam.googleapis.com", "sts.googleapis.com"]
}

run "preserve_enabled_services" {
  command = plan

  assert {
    condition     = toset(keys(google_project_service.this)) == toset(["iam.googleapis.com", "sts.googleapis.com"])
    error_message = "指定した API のみを有効にしてください。"
  }
  assert {
    condition     = alltrue([for service in google_project_service.this : !service.disable_on_destroy && service.project == "sandbox-example"])
    error_message = "破棄時に API を無効化せず、対象プロジェクトに限定してください。"
  }
}

run "empty_services" {
  command = plan
  variables {
    services = []
  }
  assert {
    condition     = length(google_project_service.this) == 0
    error_message = "空の指定では API を追加しないでください。"
  }
}

run "reject_invalid_service" {
  command = plan
  variables {
    services = ["invalid-service"]
  }
  expect_failures = [var.services]
}
