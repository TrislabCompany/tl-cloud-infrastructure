# Custom roles assignable at mg-landingzones.

# Lets a stamp's app-deploy identity change its apps' image and sizing, and
# nothing else: no listSecrets, no identity assign (ADR 0024).
resource "azurerm_role_definition" "stamp_app_deploy" {
  name              = "Stamp app deploy"
  description       = "Read and update container apps and their revisions only (ADR 0024)."
  scope             = azurerm_management_group.landingzones.id
  assignable_scopes = [azurerm_management_group.landingzones.id]

  permissions {
    actions = [
      "Microsoft.App/containerApps/read",
      "Microsoft.App/containerApps/write",
      "Microsoft.App/containerApps/revisions/*",
      "Microsoft.App/managedEnvironments/read",
      "Microsoft.App/managedEnvironments/join/action",
    ]
  }
}

# Lets global/edge and global/github read the Container Apps environments and
# the client IDs of the stamps' app-deploy identities (ADR 0027, ADR 0038).
resource "azurerm_role_definition" "edge_stamp_reader" {
  name              = "Edge stamp reader"
  description       = "Read Container Apps environments and user-assigned identities only (ADR 0027, ADR 0038)."
  scope             = azurerm_management_group.landingzones.id
  assignable_scopes = [azurerm_management_group.landingzones.id]

  permissions {
    actions = [
      "Microsoft.App/managedEnvironments/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/read",
    ]
  }
}
