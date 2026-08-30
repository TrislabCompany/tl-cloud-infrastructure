# shared-infrastructure/gcp/backend.tf
terraform {
  backend "gcs" {
    bucket = "tl-shared-infra-tofu-state-backup"
    prefix = "shared-infrastructure-gcp"
  }
}
