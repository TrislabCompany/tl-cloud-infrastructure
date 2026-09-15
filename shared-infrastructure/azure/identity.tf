# shared-infrastructure/azure/identity.tf

resource "azuread_group" "devops" {
  display_name     = "Trislab-DevOps"
  security_enabled = true
  description      = "Human engineers with Contributor over the shared-infrastructure Platform branch (mg-tl-shared-infra)."
}

resource "azurerm_role_assignment" "devops_contributor" {
  scope                = azurerm_management_group.shared_infra.id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.devops.object_id
}
