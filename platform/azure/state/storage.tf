# The state storage of 09-bootstrap.md section 5, created by hand in the seed
# and adopted here with import blocks (09-bootstrap.md section 12). Every
# setting is written as it is live, so the first plan only imports.

data "azurerm_subscription" "current" {}

locals {
  account_name   = "stplatformtfstate${var.platform_suffix}"
  group_id       = "${data.azurerm_subscription.current.id}/resourceGroups/rg-platform-state"
  account_id     = "${local.group_id}/providers/Microsoft.Storage/storageAccounts/${local.account_name}"
  containers     = toset(["tfstate-global", "tfstate-platform", "tfstate-lz", "tfstate-stamps"])
  container_root = "${local.account_id}/blobServices/default/containers"

  tags = {
    Product         = "platform"
    Customer        = "trislab"
    EnvironmentType = "prod"
    EnvironmentName = "prod"
  }

  # The seed's state rights on tfstate-platform (09-bootstrap.md section 6).
  # The object IDs are written here, not looked up, so the root needs no
  # Microsoft Graph right. The names are the generated role assignment GUIDs.
  seed_state_rights = {
    platform-plan = {
      name      = "c55c2908-8adb-4fcb-99c7-687619c5d9fb"
      role      = "Storage Blob Data Reader"
      principal = "b8f0ba1b-29df-48e3-b736-96171e65f145" # spn-platform-plan
    }
    platform-apply = {
      name      = "7239c6e8-138e-4bf5-b2b7-2d023424fa26"
      role      = "Storage Blob Data Contributor"
      principal = "be8c78c8-eba1-4c36-8be1-a4b0a2ff2fd1" # spn-platform-apply
    }
  }
}

import {
  to = azurerm_resource_group.state
  id = local.group_id
}

resource "azurerm_resource_group" "state" {
  name     = "rg-platform-state"
  location = "northeurope"
  tags     = local.tags
}

# Also blocks deleting a role assignment under the group: remove it by hand for
# that, and put it back right after (08-pipeline.md section 7).
import {
  to = azurerm_management_lock.state
  id = "${local.group_id}/providers/Microsoft.Authorization/locks/lock-rg-platform-state"
}

resource "azurerm_management_lock" "state" {
  name       = "lock-rg-platform-state"
  scope      = azurerm_resource_group.state.id
  lock_level = "CanNotDelete"
}

import {
  to = azurerm_storage_account.state
  id = local.account_id
}

# Holds every state, including this root's own: prevent_destroy keeps a
# mistaken PR from deleting it (08-pipeline.md section 7).
resource "azurerm_storage_account" "state" {
  name                            = local.account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "GZRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.containers
  to       = azurerm_storage_container.state[each.key]
  id       = "${local.container_root}/${each.key}"
}

resource "azurerm_storage_container" "state" {
  for_each           = local.containers
  name               = each.key
  storage_account_id = azurerm_storage_account.state.id
}

import {
  for_each = local.seed_state_rights
  to       = azurerm_role_assignment.seed_state[each.key]
  id       = "${local.container_root}/tfstate-platform/providers/Microsoft.Authorization/roleAssignments/${each.value.name}"
}

resource "azurerm_role_assignment" "seed_state" {
  for_each             = local.seed_state_rights
  name                 = each.value.name
  scope                = azurerm_storage_container.state["tfstate-platform"].id
  role_definition_name = each.value.role
  principal_id         = each.value.principal
}

# ---- State rights of the global and landingzones layers ---------------------
# 08-pipeline.md section 7, ADR 0032. The identities come from
# platform/azure/identity, read through spn-platform-plan's
# Application.Read.All (ADR 0034).

data "azuread_service_principal" "layer" {
  for_each     = toset(["global-plan", "global-apply", "landingzones-plan", "landingzones-apply"])
  display_name = "spn-${each.key}"
}

locals {
  # Built-in role IDs, the same in every tenant.
  blob_reader_id      = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" # Storage Blob Data Reader
  blob_contributor_id = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Blob Data Contributor

  layer_state_rights = {
    global-plan        = { container = "tfstate-global", role = "Storage Blob Data Reader" }
    global-apply       = { container = "tfstate-global", role = "Storage Blob Data Contributor" }
    landingzones-plan  = { container = "tfstate-lz", role = "Storage Blob Data Reader" }
    landingzones-apply = { container = "tfstate-lz", role = "Storage Blob Data Contributor" }
  }

  # spn-landingzones-apply may write and delete only role assignments of the
  # two blob roles, to service principals: the landing-zone module grants each
  # landing zone's identities their path on tfstate-stamps, and offboarding
  # deletes them (ADR 0032, technical details).
  stamps_grant_condition = trimspace(<<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.blob_reader_id}, ${local.blob_contributor_id}}
      AND
      @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.blob_reader_id}, ${local.blob_contributor_id}}
      AND
      @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
     )
    )
  EOT
  )
}

resource "azurerm_role_assignment" "layer_state" {
  for_each             = local.layer_state_rights
  scope                = azurerm_storage_container.state[each.value.container].id
  role_definition_name = each.value.role
  principal_id         = data.azuread_service_principal.layer[each.key].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "stamps_grant" {
  scope                = azurerm_storage_container.state["tfstate-stamps"].id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = data.azuread_service_principal.layer["landingzones-apply"].object_id
  principal_type       = "ServicePrincipal"
  condition            = local.stamps_grant_condition
  condition_version    = "2.0"
}

# A landing zone plan refreshes the role assignments the landing-zone module
# makes on tfstate-stamps. Reader holds no data action, so it opens no blob.
resource "azurerm_role_assignment" "stamps_reader" {
  scope                = azurerm_storage_container.state["tfstate-stamps"].id
  role_definition_name = "Reader"
  principal_id         = data.azuread_service_principal.layer["landingzones-plan"].object_id
  principal_type       = "ServicePrincipal"
}
