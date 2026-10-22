terraform {
  required_version = ">= 1.12.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.6"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
  }
}

# The workflows sign in to sub-platform through ARM_CLIENT_ID,
# ARM_SUBSCRIPTION_ID, ARM_TENANT_ID and ARM_USE_OIDC, which azapi and azuread
# read too. The module registers the landing zone's resource providers itself
# (05-landing-zones.md section 4.2).
provider "azurerm" {
  features {
    subscription {
      prevent_cancellation_on_destroy = true
    }
  }
  storage_use_azuread             = true
  resource_provider_registrations = "none"
}

# The landing zone's own subscription, for what goes into its resource groups.
provider "azurerm" {
  alias = "lz"
  features {}
  subscription_id                 = module.landing_zone.subscription_id
  resource_provider_registrations = "none"
}

provider "azapi" {}

provider "azuread" {}

# Writes the Environment lz-<lz>, as tl-landingzones-apply through GITHUB_TOKEN
# and GITHUB_OWNER (ADR 0019).
provider "github" {}
