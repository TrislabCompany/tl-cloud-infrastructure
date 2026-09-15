# shared-infrastructure/azure/secrets.tf
# Cosmetic touch: force a plan/apply cycle now that Digger is apply-on-merge again (#15).

# Infracost's FinOps tagging policy (Governance > Tagging policies) wants Environment
# title-cased and a Company tag, which NAMING-CONVENTIONS.md doesn't otherwise require —
# applied only to this file's resources to satisfy that check.
locals {
  infracost_tags = merge(local.mandatory_tags, {
    Environment = "Production"
    Company     = "Trislab"
  })
}

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

  tags = local.infracost_tags
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
  tags         = local.infracost_tags

  lifecycle {
    ignore_changes = [value]
  }
}
