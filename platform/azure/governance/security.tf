# The Microsoft cloud security benchmark in audit mode at mg-root, and the paid
# Defender plans prepared for prod subscriptions, switched off (ADR 0048).

locals {
  # Benchmark parameters that audit whether a Defender plan is on. The plans are
  # off on purpose, so these show no findings.
  mcsb_defender_audits = [
    "AzureDefenderForResourceManagerShouldBeEnabledMonitoringEffect",
    "AzureDefenderForOpenSourceRelationalDatabasesShouldBeEnabledMonitoringEffect",
    "MicrosoftDefenderCSPMShouldBeEnabledMonitoringEffect",
    "keyVaultsAdvancedDataSecurityMonitoringEffect",
    "sqlServersAdvancedDataSecurityMonitoringEffect",
    "sqlServersVirtualMachinesAdvancedDataSecurityMonitoringEffect",
    "sqlServerAdvancedDataSecurityMonitoringEffect",
    "sqlManagedInstanceAdvancedDataSecurityMonitoringEffect",
    "appServicesAdvancedThreatProtectionMonitoringEffect",
    "containersAdvancedThreatProtectionMonitoringEffect",
    "virtualMachinesAdvancedThreatProtectionMonitoringEffect",
    "arcEnabledKubernetesClustersShouldHaveAzureDefendersExtensionInstalled",
  ]

  # Copies of the built-in "Configure Microsoft Defender for ..." definitions,
  # saved in defender/, for the plans of ADR 0048's table.
  defender_plans = toset(["defender-arm", "defender-keyvault", "defender-ossdb", "defender-containers"])
  defender       = { for p in local.defender_plans : p => jsondecode(file("${path.module}/defender/${p}.json")) }
}

resource "azurerm_management_group_policy_assignment" "mcsb" {
  name                 = "mcsb"
  display_name         = "Microsoft cloud security benchmark"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin_set}/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  parameters           = jsonencode({ for p in local.mcsb_defender_audits : p => { value = "Disabled" } })
}

# Each copy adds one condition: the subscription name contains -prod-, so
# sandbox and experiments are never charged.
resource "azurerm_policy_definition" "defender" {
  for_each            = local.defender_plans
  name                = each.key
  display_name        = "${local.defender[each.key].displayName} (prod subscriptions)"
  description         = "Copy of the built-in ${local.defender[each.key].builtin} version ${local.defender[each.key].version}, for subscriptions whose name contains -prod- (ADR 0048)."
  policy_type         = "Custom"
  mode                = local.defender[each.key].mode
  management_group_id = azurerm_management_group.root.id
  parameters          = jsonencode(local.defender[each.key].parameters)

  policy_rule = jsonencode(merge(local.defender[each.key].policyRule, {
    if = {
      allOf = [
        local.defender[each.key].policyRule.if,
        { value = "[subscription().displayName]", contains = "-prod-" },
      ]
    }
  }))
}

resource "azurerm_management_group_policy_assignment" "defender" {
  for_each             = local.defender_plans
  name                 = each.key
  display_name         = azurerm_policy_definition.defender[each.key].display_name
  management_group_id  = azurerm_management_group.landingzones.id
  policy_definition_id = azurerm_policy_definition.defender[each.key].id
  location             = "northeurope"
  parameters           = jsonencode({ effect = { value = "Disabled" } })

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "defender" {
  for_each           = local.defender_plans
  scope              = azurerm_management_group.landingzones.id
  role_definition_id = local.role.security_admin
  principal_id       = azurerm_management_group_policy_assignment.defender[each.key].identity[0].principal_id
}
