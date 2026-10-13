# The hierarchy of 02-architecture.md section 2 (ADR 0005). The seed created
# mg-root, mg-platform and mg-experiments, placed sub-platform and gave the
# platform identities their roles (09-bootstrap.md sections 4 and 6); they are
# adopted here with import blocks (09-bootstrap.md section 12). The tenant root
# group's hierarchy settings stay outside code.

data "azurerm_client_config" "current" {}

# sub-platform, the subscription the workflows sign in to.
data "azurerm_subscription" "current" {}

locals {
  mg = "/providers/Microsoft.Management/managementGroups"

  spn_platform_plan  = "b8f0ba1b-29df-48e3-b736-96171e65f145"
  spn_platform_apply = "be8c78c8-eba1-4c36-8be1-a4b0a2ff2fd1"

  # The seed's role assignments (09-bootstrap.md section 6). The object IDs are
  # written here, not looked up, so the root needs no Microsoft Graph right.
  # The keys of the map are the generated role assignment GUIDs.
  seed_roles = {
    "1141a6c1-cb0b-4ff7-a40b-1894f0fd5c0f" = { scope = "mg-root", role = "Reader", principal = local.spn_platform_plan }
    "edf26788-8902-43ec-b1dd-21201fc60fb6" = { scope = "mg-root", role = "Management Group Contributor", principal = local.spn_platform_apply }
    "f2eabf1b-c63b-4fcc-ad1e-4996e58f825a" = { scope = "mg-root", role = "Resource Policy Contributor", principal = local.spn_platform_apply }
    "63f1571c-1638-4617-afd1-6ba956979082" = { scope = "mg-root", role = "User Access Administrator", principal = local.spn_platform_apply }
    "c270a232-5468-40fe-8c99-c01cc34f5b6f" = { scope = "mg-platform", role = "Owner", principal = local.spn_platform_apply }
  }
}

import {
  to = azurerm_management_group.root
  id = "${local.mg}/mg-root"
}

resource "azurerm_management_group" "root" {
  name                       = "mg-root"
  display_name               = "Trislab"
  parent_management_group_id = "${local.mg}/${data.azurerm_client_config.current.tenant_id}"
}

import {
  to = azurerm_management_group.platform
  id = "${local.mg}/mg-platform"
}

resource "azurerm_management_group" "platform" {
  name                       = "mg-platform"
  display_name               = "mg-platform"
  parent_management_group_id = azurerm_management_group.root.id
}

import {
  to = azurerm_management_group.experiments
  id = "${local.mg}/mg-experiments"
}

resource "azurerm_management_group" "experiments" {
  name                       = "mg-experiments"
  display_name               = "mg-experiments"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "landingzones" {
  name                       = "mg-landingzones"
  display_name               = "mg-landingzones"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "lz_standard" {
  name                       = "mg-lz-standard"
  display_name               = "mg-lz-standard"
  parent_management_group_id = azurerm_management_group.landingzones.id
}

resource "azurerm_management_group" "lz_regulated" {
  name                       = "mg-lz-regulated"
  display_name               = "mg-lz-regulated"
  parent_management_group_id = azurerm_management_group.landingzones.id
}

resource "azurerm_management_group" "decommissioned" {
  name                       = "mg-decommissioned"
  display_name               = "mg-decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}

import {
  to = azurerm_management_group_subscription_association.platform
  id = "/managementGroup/mg-platform/subscription/${data.azurerm_subscription.current.subscription_id}"
}

resource "azurerm_management_group_subscription_association" "platform" {
  management_group_id = azurerm_management_group.platform.id
  subscription_id     = data.azurerm_subscription.current.id
}

import {
  for_each = local.seed_roles
  to       = azurerm_role_assignment.seed[each.key]
  id       = "${local.mg}/${each.value.scope}/providers/Microsoft.Authorization/roleAssignments/${each.key}"
}

resource "azurerm_role_assignment" "seed" {
  for_each             = local.seed_roles
  name                 = each.key
  scope                = "${local.mg}/${each.value.scope}"
  role_definition_name = each.value.role
  principal_id         = each.value.principal
}
