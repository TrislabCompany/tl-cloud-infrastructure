# The resource group of the privatelink.* zones. No zone yet: they come with
# the first stamp template that uses a private endpoint (open question 7), each
# linked to every hub. Landing zones link their own spokes (ADR 0020).

resource "azurerm_resource_group" "dns" {
  name     = "rg-platform-dns"
  location = "northeurope"
  tags     = local.tags
}

# Lets spn-landingzones-apply read the zones and add, change and remove their
# virtual network links, and nothing else (ADR 0020).
resource "azurerm_role_definition" "dns_link" {
  name              = "Landing zone DNS link"
  description       = "Read private DNS zones and manage their virtual network links only (ADR 0020)."
  scope             = data.azurerm_subscription.current.id
  assignable_scopes = [data.azurerm_subscription.current.id]

  permissions {
    actions = [
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
    ]
  }
}

resource "azurerm_role_assignment" "dns_link" {
  scope              = azurerm_resource_group.dns.id
  role_definition_id = azurerm_role_definition.dns_link.role_definition_resource_id
  principal_id       = data.azuread_service_principal.landingzones_apply.object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "dns_reader" {
  scope                = azurerm_resource_group.dns.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_service_principal.landingzones_plan.object_id
  principal_type       = "ServicePrincipal"
}
