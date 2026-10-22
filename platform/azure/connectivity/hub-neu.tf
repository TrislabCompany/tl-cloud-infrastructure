# The hub of northeurope (02-architecture.md section 4). Its range and
# GatewaySubnet come from catalog/ipam.yaml. The GatewaySubnet stays empty
# until a stamp needs private cross-cloud traffic (vpn.tf, not written).

data "azurerm_subscription" "current" {}

locals {
  tags = {
    Product         = "platform"
    Customer        = "trislab"
    EnvironmentType = "prod"
    EnvironmentName = "prod"
  }

  hubs_neu = [
    for h in yamldecode(file("${path.module}/../../../catalog/ipam.yaml")).hubs : h
    if h.name == "vnet-hub-neu"
  ]
  hub_neu = one(local.hubs_neu)
}

# The landing zone pipeline's identities (platform/azure/identity), read through
# spn-platform-plan's Application.Read.All (ADR 0018, ADR 0034).
data "azuread_service_principal" "landingzones_apply" {
  display_name = "spn-landingzones-apply"
}

data "azuread_service_principal" "landingzones_plan" {
  display_name = "spn-landingzones-plan"
}

resource "azurerm_resource_group" "hub_neu" {
  name     = "rg-hub-neu"
  location = "northeurope"
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub_neu" {
  name                = "vnet-hub-neu"
  resource_group_name = azurerm_resource_group.hub_neu.name
  location            = azurerm_resource_group.hub_neu.location
  address_space       = [local.hub_neu.cidr]
  tags                = local.tags

  lifecycle {
    # A hub's cidr equals its range in catalog/ipam.yaml (07 section 7).
    precondition {
      condition     = length(local.hubs_neu) == 1 && local.hub_neu.cloud == "azure" && local.hub_neu.region == azurerm_resource_group.hub_neu.location
      error_message = "catalog/ipam.yaml must hold vnet-hub-neu exactly once, as an azure hub in northeurope (07 section 5)."
    }
  }
}

resource "azurerm_subnet" "gateway_neu" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub_neu.name
  virtual_network_name = azurerm_virtual_network.hub_neu.name
  address_prefixes     = [local.hub_neu.subnets.GatewaySubnet]
}

# The landing-zone module creates both halves of its peering (ADR 0018).
resource "azurerm_role_assignment" "hub_neu_peering" {
  scope              = azurerm_virtual_network.hub_neu.id
  role_definition_id = azurerm_role_definition.hub_peering.role_definition_resource_id
  principal_id       = data.azuread_service_principal.landingzones_apply.object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "hub_neu_reader" {
  scope                = azurerm_virtual_network.hub_neu.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_service_principal.landingzones_plan.object_id
  principal_type       = "ServicePrincipal"
}
