# The policy assignments per scope of 02-architecture.md section 2 (ADR 0005).
# The SKU lists, sizing ceilings, backup rule and platform resource types wait
# for open question 18, and the mg-lz-regulated policies for open question 19
# (TODO.md, ADR 0054). Assignment names are at most 24 characters
# (03-naming-conventions.md sections 7.2 and 10). Each assignment that remediates
# has a system-assigned identity with the roles its definition names.

locals {
  builtin     = "/providers/Microsoft.Authorization/policyDefinitions"
  builtin_set = "/providers/Microsoft.Authorization/policySetDefinitions"

  # The active Azure regions of catalog/regions.yaml (07 section 10, N6).
  regions = [
    for r in yamldecode(file("${path.module}/../../../catalog/regions.yaml")).regions :
    r.name if r.cloud == "azure" && r.state == "active"
  ]

  # log-platform, created by platform/azure/management in step A7. Built from
  # its name, so this root doesn't depend on that one.
  log_platform_id = "${data.azurerm_subscription.current.id}/resourceGroups/rg-platform-management/providers/Microsoft.OperationalInsights/workspaces/log-platform"

  tag_names = ["Product", "Customer", "EnvironmentType", "EnvironmentName"]

  # Resource groups that Azure creates for a service, such as a Container Apps
  # environment's rg-<stamp>-infra (03-naming-conventions.md section 7.4) or
  # Azure's default ME_, MC_ and MA_ groups. A policy can't read a resource
  # group's managedBy, so these are told apart by their name.
  azure_managed_groups = [
    { field = "name", notLike = "ME_*" },
    { field = "name", notLike = "MC_*" },
    { field = "name", notLike = "MA_*" },
    { field = "name", notLike = "*-infra" },
  ]

  is_resource_group = { field = "type", equals = "Microsoft.Resources/subscriptions/resourceGroups" }

  role = {
    contributor           = "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
    log_analytics_contrib = "/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293"
    security_admin        = "/providers/Microsoft.Authorization/roleDefinitions/fb1c8493-542b-48eb-b624-b4c8fea62acd"
  }
}

# ---- mg-root ----------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  parameters           = jsonencode({ listOfAllowedLocations = { value = local.regions } })

  non_compliance_message {
    content = "Only the active Azure regions of catalog/regions.yaml are allowed (N6)."
  }
}

resource "azurerm_management_group_policy_assignment" "allowed_rg_locations" {
  name                 = "allowed-rg-locations"
  display_name         = "Allowed locations for resource groups"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/e765b5de-1225-4ba3-bd56-1ac6695af988"
  parameters           = jsonencode({ listOfAllowedLocations = { value = local.regions } })

  non_compliance_message {
    content = "Only the active Azure regions of catalog/regions.yaml are allowed (N6)."
  }
}

resource "azurerm_policy_definition" "require_rg_tags" {
  name                = "require-rg-tags"
  display_name        = "Resource groups carry the four mandatory tags"
  description         = "Denies a resource group without Product, Customer, EnvironmentType and EnvironmentName, or with an EnvironmentType other than prod or sandbox (03-naming-conventions.md sections 9 and 11)."
  policy_type         = "Custom"
  mode                = "All"
  management_group_id = azurerm_management_group.root.id

  policy_rule = jsonencode({
    if = {
      allOf = concat([local.is_resource_group], local.azure_managed_groups, [{
        anyOf = concat(
          [for t in local.tag_names : { field = "tags['${t}']", exists = "false" }],
          [{ field = "tags['EnvironmentType']", notIn = ["prod", "sandbox"] }],
        )
      }])
    }
    then = { effect = "deny" }
  })
}

resource "azurerm_management_group_policy_assignment" "require_rg_tags" {
  name                 = "require-rg-tags"
  display_name         = "Resource groups carry the four mandatory tags"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = azurerm_policy_definition.require_rg_tags.id

  non_compliance_message {
    content = "A resource group needs the tags Product, Customer, EnvironmentType (prod or sandbox) and EnvironmentName (03 section 9)."
  }
}

resource "azurerm_management_group_policy_set_definition" "inherit_rg_tags" {
  name                = "inherit-rg-tags"
  display_name        = "Resources inherit the four mandatory tags from their resource group"
  policy_type         = "Custom"
  management_group_id = azurerm_management_group.root.id

  dynamic "policy_definition_reference" {
    for_each = local.tag_names
    content {
      policy_definition_id = "${local.builtin}/ea3f2387-9b95-492a-a190-fcdc54f7b070"
      reference_id         = "inherit-${lower(policy_definition_reference.value)}"
      parameter_values     = jsonencode({ tagName = { value = policy_definition_reference.value } })
    }
  }
}

resource "azurerm_management_group_policy_assignment" "inherit_rg_tags" {
  name                 = "inherit-rg-tags"
  display_name         = "Resources inherit the four mandatory tags from their resource group"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = azurerm_management_group_policy_set_definition.inherit_rg_tags.id
  location             = "northeurope"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "inherit_rg_tags" {
  scope              = azurerm_management_group.root.id
  role_definition_id = local.role.contributor
  principal_id       = azurerm_management_group_policy_assignment.inherit_rg_tags.identity[0].principal_id
}

resource "azurerm_management_group_policy_assignment" "diagnostics" {
  name                 = "diagnostics"
  display_name         = "Resource logs to log-platform"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin_set}/0884adba-2312-4468-abeb-5422caed1038"
  location             = "northeurope"
  parameters           = jsonencode({ logAnalytics = { value = local.log_platform_id } })

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "diagnostics" {
  scope              = azurerm_management_group.root.id
  role_definition_id = local.role.log_analytics_contrib
  principal_id       = azurerm_management_group_policy_assignment.diagnostics.identity[0].principal_id
}

resource "azurerm_management_group_policy_assignment" "blob_no_public" {
  name                 = "blob-no-public"
  display_name         = "Storage account public access should be disallowed"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
  parameters           = jsonencode({ effect = { value = "Deny" } })
}

resource "azurerm_management_group_policy_assignment" "storage_tls12" {
  name                 = "storage-tls12"
  display_name         = "Storage accounts use TLS 1.2 or later"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/fe83a0eb-a853-422d-aac2-1bffd182c5d0"
  parameters = jsonencode({
    effect            = { value = "Deny" }
    minimumTlsVersion = { value = "TLS1_2" }
  })
}

# ---- mg-landingzones --------------------------------------------------------

# A policy like value may hold only one wildcard, so the subscription name is
# tested with contains (02-architecture.md section 2).
resource "azurerm_policy_definition" "envtype_by_name" {
  name                = "envtype-by-name"
  display_name        = "EnvironmentType matches the subscription name"
  description         = "Denies a resource group whose EnvironmentType differs from the environment type in the subscription name (03-naming-conventions.md section 11)."
  policy_type         = "Custom"
  mode                = "All"
  management_group_id = azurerm_management_group.root.id

  policy_rule = jsonencode({
    if = {
      allOf = concat([local.is_resource_group], local.azure_managed_groups, [{
        anyOf = [for t in ["prod", "sandbox"] : {
          allOf = [
            { value = "[subscription().displayName]", contains = "-${t}-" },
            { field = "tags['EnvironmentType']", notEquals = t },
          ]
        }]
      }])
    }
    then = { effect = "deny" }
  })
}

resource "azurerm_management_group_policy_assignment" "envtype_by_name" {
  name                 = "envtype-by-name"
  display_name         = "EnvironmentType matches the subscription name"
  management_group_id  = azurerm_management_group.landingzones.id
  policy_definition_id = azurerm_policy_definition.envtype_by_name.id

  non_compliance_message {
    content = "EnvironmentType must equal the environment type in the subscription name (03 section 11)."
  }
}

# ---- mg-experiments ---------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "exp_no_network" {
  name                 = "exp-no-network"
  display_name         = "No peering, VPN or ExpressRoute in experiments"
  management_group_id  = azurerm_management_group.experiments.id
  policy_definition_id = "${local.builtin}/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
  parameters = jsonencode({
    listOfResourceTypesNotAllowed = { value = [
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
      "Microsoft.Network/virtualNetworkGateways",
      "Microsoft.Network/connections",
      "Microsoft.Network/vpnGateways",
      "Microsoft.Network/expressRouteCircuits",
      "Microsoft.Network/expressRouteGateways",
    ] }
  })

  non_compliance_message {
    content = "An experiment can't connect to any network (ADR 0051)."
  }
}

resource "azurerm_policy_definition" "envtype_fixed" {
  name                = "envtype-fixed"
  display_name        = "EnvironmentType has a fixed value"
  description         = "Denies a resource group whose EnvironmentType differs from the parameter (02-architecture.md section 2)."
  policy_type         = "Custom"
  mode                = "All"
  management_group_id = azurerm_management_group.root.id

  parameters = jsonencode({
    environmentType = { type = "String", allowedValues = ["prod", "sandbox"] }
  })

  policy_rule = jsonencode({
    if = {
      allOf = concat([local.is_resource_group], local.azure_managed_groups, [
        { field = "tags['EnvironmentType']", notEquals = "[parameters('environmentType')]" },
      ])
    }
    then = { effect = "deny" }
  })
}

resource "azurerm_management_group_policy_assignment" "envtype_sandbox" {
  name                 = "envtype-sandbox"
  display_name         = "EnvironmentType is sandbox in experiments"
  management_group_id  = azurerm_management_group.experiments.id
  policy_definition_id = azurerm_policy_definition.envtype_fixed.id
  parameters           = jsonencode({ environmentType = { value = "sandbox" } })

  non_compliance_message {
    content = "Every resource group in an experiment has EnvironmentType sandbox (ADR 0051)."
  }
}

# ---- mg-decommissioned ------------------------------------------------------

# Policy never evaluates a delete, so the offboarding apply can still remove
# what is left (12-offboarding.md section 4).
resource "azurerm_policy_definition" "deny_writes" {
  name                = "deny-writes"
  display_name        = "Deny all writes"
  description         = "Denies creating or changing any resource (02-architecture.md section 2)."
  policy_type         = "Custom"
  mode                = "All"
  management_group_id = azurerm_management_group.root.id

  policy_rule = jsonencode({
    if   = { field = "type", notEquals = "" }
    then = { effect = "deny" }
  })
}

resource "azurerm_management_group_policy_assignment" "deny_writes" {
  name                 = "deny-writes"
  display_name         = "Deny all writes in mg-decommissioned"
  management_group_id  = azurerm_management_group.decommissioned.id
  policy_definition_id = azurerm_policy_definition.deny_writes.id

  non_compliance_message {
    content = "This landing zone is being decommissioned: nothing in it can be created or changed (12 section 4)."
  }
}
