# Management group hierarchy and guardrail policy for the TL tenant.
resource "azurerm_management_group" "tl" {
  name         = "mg-tl"
  display_name = "TL"
  # No parent_management_group_id — defaults to the Tenant Root Group.
}

resource "azurerm_management_group" "shared_infra" {
  name                       = "mg-tl-shared-infra"
  display_name               = "TL Shared Infrastructure"
  parent_management_group_id = azurerm_management_group.tl.id
}

resource "azurerm_management_group" "products" {
  name                       = "mg-tl-products"
  display_name               = "TL Products"
  parent_management_group_id = azurerm_management_group.tl.id
}

resource "azurerm_management_group" "customers" {
  name                       = "mg-tl-customers"
  display_name               = "TL Customers"
  parent_management_group_id = azurerm_management_group.tl.id
}

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations-mg-tl"
  management_group_id  = azurerm_management_group.tl.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  display_name         = "Allowed locations (mg-tl)"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["westeurope", "northeurope"]
    }
  })
}

# FinOps action group and shared-infra budget — Phase 5, Step 3.
resource "azurerm_resource_group" "governance" {
  name     = "rg-tl-shared-infra-governance-neu"
  location = "northeurope"

  tags = {
    Customer        = "trislab"
    Product         = "shared-infra"
    Environment     = "production"
    EnvironmentName = "prod"
  }
}

resource "azurerm_monitor_action_group" "finops_email" {
  name                = "ag-tl-finops-email"
  resource_group_name = azurerm_resource_group.governance.name
  short_name          = "tlfinops" # 12-char limit, alphanumeric only — see NAMING-CONVENTIONS.md's ag row

  email_receiver {
    name                    = "finops-mailbox"
    email_address           = "finops@trislab.si"
    use_common_alert_schema = true
  }

  tags = {
    Customer        = "trislab"
    Product         = "shared-infra"
    Environment     = "production"
    EnvironmentName = "prod"
  }
}

resource "azurerm_consumption_budget_subscription" "shared_infra" {
  name            = "budget-tl-shared-infra-azure"
  subscription_id = "/subscriptions/${var.azure_subscription_id}"

  amount     = 200
  time_grain = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z" # first of next month at apply time — see step-03-cost-management.md troubleshooting
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_groups = [azurerm_monitor_action_group.finops_email.id]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_groups = [azurerm_monitor_action_group.finops_email.id]
  }
}
