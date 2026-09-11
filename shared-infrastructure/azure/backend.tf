# shared-infrastructure/azure/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tl-shared-infra-state-neu"
    storage_account_name = "sttlsharedinfraneu"
    container_name       = "tofu-state"
    key                  = "shared-infrastructure-azure.tfstate"
    use_azuread_auth     = true
  }
}
