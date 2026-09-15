# shared-infrastructure/azure/secrets.tf

resource "azurerm_key_vault" "shared_infra" {
  name                = "kv-tl-shared-infra"
  resource_group_name = azurerm_resource_group.governance.name
  location            = azurerm_resource_group.governance.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization  = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.mandatory_tags
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "devops_secrets_officer" {
  scope                = azurerm_key_vault.shared_infra.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azuread_group.devops.object_id
}

resource "azurerm_key_vault_secret" "break_glass_credential" {
  name         = "break-glass-credential"
  key_vault_id = azurerm_key_vault.shared_infra.id
  value        = "REPLACE-MANUALLY-SEE-STEP-5"

  lifecycle {
    ignore_changes = [value]
  }
}
