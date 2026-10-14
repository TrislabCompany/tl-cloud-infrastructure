# The platform Key Vault of 02-architecture.md section 6 (Secrets). The copies
# of the state passphrases are typed in by hand (ADR 0046), so no secret is
# written here. The contacts-<code> placeholders come with the first active
# customer in catalog/owners.yaml (ADR 0050).

data "azurerm_client_config" "current" {}

locals {
  # Written here, not looked up, so spn-platform-plan needs no Microsoft Graph
  # right. Created by platform/azure/identity.
  grp_platform_admins = "ef49c472-4301-480b-a70e-19d6ca240357"
}

# Keeps its public endpoint, listed in .prowler-exceptions.yaml
# (02-architecture.md section 6).
resource "azurerm_key_vault" "platform" {
  name                       = "kv-platform-${var.platform_suffix}"
  resource_group_name        = azurerm_resource_group.management.name
  location                   = azurerm_resource_group.management.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  tags                       = local.tags
}

# Direct while Entra ID P2 isn't bought (ADR 0053).
resource "azurerm_role_assignment" "platform_admins_secrets" {
  scope                = azurerm_key_vault.platform.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = local.grp_platform_admins
  principal_type       = "Group"
}
