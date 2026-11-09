terraform {
  required_version = ">= 1.12.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.6"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }
}

# Reads the organization as tl-github-plan on plan, and writes it as
# tl-github-apply on apply, through GITHUB_TOKEN and GITHUB_OWNER (ADR 0038).
provider "github" {}

# The workflows sign in as spn-global-plan or spn-global-apply through
# ARM_CLIENT_ID, ARM_TENANT_ID and ARM_USE_OIDC.
provider "azapi" {}

# Creates the deploy tokens of the sites on Cloudflare Pages (pages.tf), signed
# in through CLOUDFLARE_API_TOKEN as global/edge is: the read-only token on
# plan, the edit token of the Environment global on apply (16-secrets.md
# section 7).
provider "cloudflare" {}
