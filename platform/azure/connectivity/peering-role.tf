# Lets spn-landingzones-apply read a hub and add, change and remove its
# peerings, and nothing else. Assigned per hub VNet in hub-<code>.tf
# (ADR 0018).
resource "azurerm_role_definition" "hub_peering" {
  name              = "Landing zone hub peering"
  description       = "Read a hub VNet and manage its peerings only (ADR 0018)."
  scope             = data.azurerm_subscription.current.id
  assignable_scopes = [data.azurerm_subscription.current.id]

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/virtualNetworks/peer/action",
    ]
  }
}
