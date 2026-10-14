# Platform alerts by e-mail (02-architecture.md section 9).

resource "azurerm_monitor_action_group" "platform" {
  name                = "ag-platform"
  resource_group_name = azurerm_resource_group.management.name
  short_name          = "ag-platform"
  tags                = local.tags

  email_receiver {
    name                    = "platform"
    email_address           = var.alert_email_platform
    use_common_alert_schema = true
  }
}

# Any Azure operation by an emergency access account (ADR 0047). Stateful, so
# one operation sends one e-mail although the window overlaps the next run.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "emergency_access" {
  name                    = "emergency-access"
  resource_group_name     = azurerm_resource_group.management.name
  location                = azurerm_resource_group.management.location
  description             = "An emergency access account made an Azure operation (ADR 0047)."
  scopes                  = [azurerm_log_analytics_workspace.platform.id]
  severity                = 0
  evaluation_frequency    = "PT5M"
  window_duration         = "PT15M"
  auto_mitigation_enabled = true
  tags                    = local.tags

  criteria {
    query                   = <<-KQL
      AzureActivity
      | where Caller in~ ("emergency-admin-01@trislab.com", "emergency-admin-02@trislab.com")
      KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      number_of_evaluation_periods             = 1
      minimum_failing_periods_to_trigger_alert = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.platform.id]
  }
}
