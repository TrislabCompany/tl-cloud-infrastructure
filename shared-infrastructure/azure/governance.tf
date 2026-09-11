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
