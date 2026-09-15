# shared-infrastructure/azure/bootstrap.tf
#
# Permissions the pipeline identities need on themselves. See step-04-identity.md and
# step-05-key-vault.md for the rationale — including why Microsoft Graph permissions
# are deliberately NOT managed here.

locals {
  apply_identity_object_id = "32663278-c02d-40c7-953d-4529e9c13d57" # spn-tl-github-sharedinfra-azure-apply

  privileged_role_definition_ids = [
    "8e3af657-a8ff-443c-a75c-2fe8c4bcb635", # Owner
    "f58310d9-a9f6-439a-9e8d-f62e7b41a168", # Role Based Access Control Administrator
    "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9", # User Access Administrator
  ]

  no_privilege_escalation_condition = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {${join(", ", local.privileged_role_definition_ids)}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {${join(", ", local.privileged_role_definition_ids)}}))"
}

resource "azurerm_role_assignment" "apply_identity_rbac_administrator" {
  scope                = azurerm_management_group.tl.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id          = local.apply_identity_object_id
  condition             = local.no_privilege_escalation_condition
  condition_version     = "2.0"
}

resource "azurerm_role_assignment" "apply_identity_resource_policy_contributor" {
  scope                = azurerm_management_group.tl.id
  role_definition_name = "Resource Policy Contributor"
  principal_id         = local.apply_identity_object_id
}
