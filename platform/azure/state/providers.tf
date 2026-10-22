terraform {
  required_version = ">= 1.12.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
  }
}

# The workflows sign in to sub-platform through ARM_CLIENT_ID,
# ARM_SUBSCRIPTION_ID, ARM_TENANT_ID and ARM_USE_OIDC, which azuread reads too.
provider "azurerm" {
  features {}
  storage_use_azuread = true
}

provider "azuread" {}
