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

# A budget that names the action group is created only by a caller that can
# read it: without this, every landing zone budget fails with a bare 401.
resource "azurerm_role_assignment" "finops_landingzones" {
  scope                = azurerm_monitor_action_group.finops.id
  role_definition_name = "Monitoring Reader"
  principal_id         = "d6b74fa7-b0bf-4f6c-855b-13e086fb9bc6" # spn-landingzones-apply
  principal_type       = "ServicePrincipal"
}
