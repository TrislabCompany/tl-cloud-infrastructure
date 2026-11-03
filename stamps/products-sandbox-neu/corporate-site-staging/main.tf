# stamps/products-sandbox-neu/corporate-site-staging/main.tf (generated, never hand-edited)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-state"
    storage_account_name = "stplatformtfstate6884"
    container_name       = "tfstate-stamps"
    key                  = "products-sandbox-neu/corporate-site-staging.tfstate"
    use_oidc             = true
    use_azuread_auth     = true # shared key access is off on the state storage
  }
}

provider "azurerm" {
  features {
    key_vault { recover_soft_deleted_secrets = true }
  }
  use_oidc                        = true # client ID and subscription ID come from the lz-products-sandbox-neu Environment
  storage_use_azuread             = true
  resource_provider_registrations = "none" # the landing zone registers them (05 section 4.2)
}

variable "data_access" { # from DATA_READERS_OBJECT_ID and DATA_ADMINS_OBJECT_ID in lz-products-sandbox-neu
  type = object({ readers = string, admins = string })
}
variable "github_owner_id" { # the run's github.repository_owner_id
  type = number
}
variable "app_repo_ids" { # from APP_REPO_IDS in lz-products-sandbox-neu
  type    = map(number)
  default = {}
}
variable "origin_cert_versions" { # from ORIGIN_CERT_<ZONE>_VERSION in lz-products-sandbox-neu
  type    = map(number)
  default = {}
}
variable "edge_hostnames" { # from EDGE_HOSTNAMES in lz-products-sandbox-neu
  type    = list(string)
  default = []
}
variable "origin_certs" { # from the secrets ORIGIN_CERT_<ZONE> in lz-products-sandbox-neu, apply only
  type      = map(string)
  default   = {}
  sensitive = true
  ephemeral = true
}
variable "ghcr_pull_token_version" { # from GHCR_PULL_TOKEN_VERSION in lz-products-sandbox-neu
  type    = number
  default = null # null fails the plan: the landing zone has no pull token yet (section 6.3)
}
variable "ghcr_pull_token" { # from the secret GHCR_PULL_TOKEN in lz-products-sandbox-neu, apply only
  type      = string
  default   = null
  sensitive = true
  ephemeral = true
}

module "stamp" {
  source = "git::https://github.com/TrislabCompany/tl-platform.git//stamps/aca-app?ref=aca-app/v1.0.2"
  config = yamldecode(file("${path.module}/stamp.yaml"))
  lz     = yamldecode(file("${path.root}/../../../landing-zones/products-sandbox-neu.yaml"))
  tenants = [for t in yamldecode(file("${path.root}/../../../catalog/tenants.yaml")).tenants : t
  if t.stamp == "products-sandbox-neu/corporate-site-staging"]
  cloudflare_ips          = yamldecode(file("${path.root}/../../../catalog/cloudflare-ips.yaml"))
  data_access             = var.data_access
  github_owner_id         = var.github_owner_id
  app_repo_ids            = var.app_repo_ids
  origin_cert_versions    = var.origin_cert_versions
  edge_hostnames          = var.edge_hostnames
  origin_certs            = var.origin_certs
  ghcr_pull_token_version = var.ghcr_pull_token_version
  ghcr_pull_token         = var.ghcr_pull_token
}

output "stamp" { value = module.stamp }
