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

  # Temporarily open — see step-05-key-vault.md for why "Deny" blocks the
  # apply identity today and the plan to revert this once Phase 6's Private
  # Endpoint exists. RBAC (not network) still gates who can read/write secrets.
  # trivy:ignore:AVD-AZU-0013 known/accepted, see step-05-key-vault.md
  network_acls {
    default_action = "Allow"
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

# Apply identity's own data-plane grant on this vault — see step-05-key-vault.md for why.
resource "azurerm_role_assignment" "apply_identity_secrets_officer" {
  scope                = azurerm_key_vault.shared_infra.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = local.apply_identity_object_id
}

# Read-only grant so `tofu plan` can refresh azurerm_key_vault_secret.break_glass_credential's
# state without erroring — the plan identity never needs to write secrets, only read them.
resource "azurerm_role_assignment" "plan_identity_secrets_user" {
  scope                = azurerm_key_vault.shared_infra.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.plan_identity_object_id
}

# Wait for RBAC propagation before the first secret operation depending on it.
resource "time_sleep" "wait_for_apply_identity_rbac" {
  depends_on      = [azurerm_role_assignment.apply_identity_secrets_officer, azurerm_role_assignment.plan_identity_secrets_user]
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
