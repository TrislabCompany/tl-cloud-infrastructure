terraform {
  required_version = ">= 1.12.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.6"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
  }
}

# The workflows sign in to Cloudflare through CLOUDFLARE_API_TOKEN: the
# read-only token on plan, the edit token of the Environment global on apply
# (16-secrets.md section 7).
provider "cloudflare" {}

# The workflows sign in as spn-global-plan or spn-global-apply through
# ARM_CLIENT_ID, ARM_TENANT_ID and ARM_USE_OIDC.
provider "azuread" {}

provider "azapi" {}

# Reads the Environments lz-<lz> as tl-landingzones-plan on plan, and writes
# them as tl-global-apply on apply, through GITHUB_TOKEN and GITHUB_OWNER
# (ADR 0026, ADR 0027).
provider "github" {}
