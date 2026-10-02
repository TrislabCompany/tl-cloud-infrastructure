terraform {
  required_version = ">= 1.12.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
  }
}

# The workflows sign in to sub-platform through ARM_CLIENT_ID,
# ARM_SUBSCRIPTION_ID, ARM_TENANT_ID and ARM_USE_OIDC.
provider "azurerm" {
  features {}
  storage_use_azuread = true
}
