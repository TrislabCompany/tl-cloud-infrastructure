# shared-infrastructure/azure/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name = "rg-tl-shared-infra-state-weu"
    storage_account_name = "sttlsharedinfraweu"
    container_name        = "tofu-state"
    key                    = "shared-infrastructure-azure.tfstate"
  }
}
