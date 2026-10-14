# The central workspace of 02-architecture.md section 9. The resource logs
# reach it through the diagnostics policy of platform/azure/governance. The
# Entra sign-in and audit logs wait for Entra ID P1 (ADR 0047).

data "azurerm_subscription" "current" {}

locals {
  tags = {
    Product         = "platform"
    Customer        = "trislab"
    EnvironmentType = "prod"
    EnvironmentName = "prod"
  }

  activity_log_categories = [
    "Administrative", "Security", "ServiceHealth", "Alert",
    "Recommendation", "Policy", "Autoscale", "ResourceHealth",
  ]
}

resource "azurerm_resource_group" "management" {
  name     = "rg-platform-management"
  location = "northeurope"
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = "log-platform"
  resource_group_name = azurerm_resource_group.management.name
  location            = azurerm_resource_group.management.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# The landing zone subscriptions send theirs from the landing-zone module.
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-log"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  dynamic "enabled_log" {
    for_each = toset(local.activity_log_categories)
    content {
      category = enabled_log.value
    }
  }
}
