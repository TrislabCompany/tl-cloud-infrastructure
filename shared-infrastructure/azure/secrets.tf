# shared-infrastructure/azure/secrets.tf

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

# The Digger apply identity itself (spn-tl-github-sharedinfra-azure-apply) also needs a
# data-plane role on this vault: enable_rbac_authorization means its Contributor grant on
# mg-tl-shared-infra (management plane only) doesn't cover secrets.getSecret/setSecret, so
# without this the apply that creates the vault fails to then create the secret below
# (403 ForbiddenByRbac).
data "azuread_service_principal" "apply_identity" {
  client_id = "01c8452f-a291-47d8-ba0f-3f1a358c094d" # spn-tl-github-sharedinfra-azure-apply
}

resource "azurerm_role_assignment" "apply_identity_secrets_officer" {
  scope                = azurerm_key_vault.shared_infra.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_service_principal.apply_identity.object_id
}

# RBAC role assignments can take up to a couple of minutes to propagate to the Key Vault
# data plane, so give it a moment before the first secret operation depending on it.
resource "time_sleep" "wait_for_apply_identity_rbac" {
  depends_on      = [azurerm_role_assignment.apply_identity_secrets_officer]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "break_glass_credential" {
  name         = "break-glass-credential"
  key_vault_id = azurerm_key_vault.shared_infra.id
  value        = "REPLACE-MANUALLY-SEE-STEP-5"
  tags         = local.infracost_tags

  depends_on = [time_sleep.wait_for_apply_identity_rbac]

  lifecycle {
    ignore_changes = [value]
  }
}
