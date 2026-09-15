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
