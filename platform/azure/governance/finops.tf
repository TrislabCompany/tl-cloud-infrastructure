# The shared FinOps action group that every landing zone budget alerts through
# (03-naming-conventions.md section 7.2).

resource "azurerm_resource_group" "governance" {
  name     = "rg-platform-governance"
  location = "northeurope"

  tags = {
    Product         = "platform"
    Customer        = "trislab"
    EnvironmentType = "prod"
    EnvironmentName = "prod"
  }
}

resource "azurerm_monitor_action_group" "finops" {
  name                = "ag-finops"
  resource_group_name = azurerm_resource_group.governance.name
  short_name          = "ag-finops"
  tags                = azurerm_resource_group.governance.tags

  email_receiver {
    name                    = "finops"
    email_address           = var.alert_email_finops
    use_common_alert_schema = true
  }
}
