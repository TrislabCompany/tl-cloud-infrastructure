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
