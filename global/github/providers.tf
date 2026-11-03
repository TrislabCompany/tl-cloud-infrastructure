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
  }
}

# Reads the organization as tl-github-plan on plan, and writes it as
# tl-github-apply on apply, through GITHUB_TOKEN and GITHUB_OWNER (ADR 0038).
provider "github" {}

# The workflows sign in as spn-global-plan or spn-global-apply through
# ARM_CLIENT_ID, ARM_TENANT_ID and ARM_USE_OIDC.
provider "azapi" {}
