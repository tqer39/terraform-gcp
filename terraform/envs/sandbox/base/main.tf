locals {
  config = jsondecode(file("${path.module}/sandbox.json"))
}

provider "google" {
  project = local.config.project_id
  region  = local.config.region
}

module "project_services" {
  source     = "../../../modules/project_services"
  project_id = local.config.project_id
  services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]
}

module "github_oidc" {
  source            = "../../../modules/github_oidc"
  project_id        = local.config.project_id
  github_repository = local.config.github_repository
  project_roles = [
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.objectAdmin",
  ]

  depends_on = [module.project_services]
}
