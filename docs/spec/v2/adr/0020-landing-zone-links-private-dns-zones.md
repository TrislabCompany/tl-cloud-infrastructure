# ADR 0020: The landing zone pipeline links the private DNS zones to its own spoke

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

When an app talks to a database over a private endpoint, it looks up a name like `mydb.privatelink.postgres.database.azure.com`. The answer, a private IP address, is kept in a shared private phone book: the `privatelink.*` private DNS zones in platform connectivity. A network can only read a phone book that has been linked to it. A spoke without the links gets the public address, or nothing, and the connection fails.

[04](../04-repository-structure.md) puts these links in `platform/azure/connectivity`. Then every new landing zone would need a second PR in the `platform` layer, and between the two applies its stamps couldn't reach their private endpoints. That breaks "a new landing zone is one file". We have to decide who creates the links, and with what rights.

Example: creating `cust-vbs-prod-sec` needs a link from each `privatelink.*` zone to `vnet-cust-vbs-prod-sec`, before its first stamp creates a private endpoint.

## The decision

The `landing-zone` module creates and removes the links from every `privatelink.*` zone to its own spoke, in the same apply as the spoke. A custom role, **"Landing zone DNS link"**, allows only reading the zones and adding, changing and removing their virtual network links. `platform/azure/connectivity` keeps the zones in one resource group, `rg-platform-dns`, and assigns the role to `spn-landingzones-apply` on that resource group.

## What this means in practice

- A new landing zone is still one file and one PR. Its spoke can resolve private endpoints as soon as the apply finishes.
- Decommissioning removes the links in the same apply, together with the peering.
- The landing zone pipeline can't create or delete zones or change their records. It can add or remove *any* link on the zones, including another landing zone's. Plan review and nightly drift detection catch a wrong change, as with the peering in [ADR 0018](./0018-hub-peering-custom-role.md).
- A new `privatelink.*` zone is added only in `connectivity`. The next `landing-zones/_root` apply links it to every spoke. Until then, spokes don't resolve names in the new zone, so a zone is added before the stamp template that needs it.
- Stamps don't need the links themselves, only the records their private endpoints write. Who grants that is not decided here (see technical details).

## Options we did not choose

| Option | Why not |
|---|---|
| `connectivity` reads `landing-zones/*.yaml` and links every spoke (as in [04](../04-repository-structure.md) today) | Every new or decommissioned landing zone needs a second PR in the `platform` layer, and stamps fail until it is applied. It breaks "a new landing zone is one file". Same reason as in [ADR 0018](./0018-hub-peering-custom-role.md) |
| Link the zones only to the hub, and point every spoke's DNS at an Azure DNS Private Resolver in the hub | No per-spoke links. But it costs a resolver endpoint per region (roughly €170 a month each), adds a component on every name lookup, and the landing zone would still need to set its spoke's DNS servers to the resolver. Worth revisiting if the link count ever becomes a problem |
| Private DNS Zone Contributor on `rg-platform-dns` | Also allows deleting zones and changing every record. One wrong landing zone PR could break private endpoint resolution for every landing zone |
| Private DNS zones per landing zone, in its own subscription | Each landing zone would resolve only its own endpoints, and shared platform endpoints (for example `kv-platform-1307`) would need a second zone with the same name. Azure recommends one central set of zones |

## Technical details

- **Role actions:**

  | Action | Why |
  |---|---|
  | `Microsoft.Network/privateDnsZones/read` | Find the zones with a data source |
  | `Microsoft.Network/privateDnsZones/virtualNetworkLinks/read`, `/write`, `/delete` | Create, update and remove the link |

  Creating a link also needs `Microsoft.Network/virtualNetworks/join/action` on the spoke. `spn-landingzones-apply` already has it, because it creates the spoke in the landing zone's subscription.
- **Where it is defined and when it is assigned:** all in `platform/azure/connectivity`, applied by `spn-platform-apply`, with no manual step.

  | What | File | When |
  |---|---|---|
  | Resource group `rg-platform-dns` and the `privatelink.*` zones, each linked to every hub VNet | `private-dns.tf` | The first `connectivity` apply. Links to a new hub are added in the same apply that creates the hub |
  | Role definition "Landing zone DNS link". Assignable scope: the connectivity subscription (`sub-platform` in the MVP) | `private-dns.tf` | Same apply |
  | This role for `spn-landingzones-apply`, and Reader for `spn-landingzones-plan`, on `rg-platform-dns` | `private-dns.tf` | Same apply |

  The role is separate from "Landing zone hub peering" because its scope is different: a resource group of zones, not a hub VNet.
- **Module:** the `landing-zone` module lists the zones with an `azurerm_resources` data source (type `Microsoft.Network/privateDnsZones`, resource group `rg-platform-dns`) and creates one `azurerm_private_dns_zone_virtual_network_link` per zone, named `vnetl-<lz>` with `registration_enabled = false`. It uses the same connectivity provider alias as the hub peering. If the role assignment is missing, the plan fails at the data source, before anything is created.
- **Limits:** a private DNS zone takes up to 1,000 virtual network links, so the zones support about 1,000 spokes plus the hubs. Role assignment conditions can't limit link writes to one VNet.
- **GCP:** private zones list their networks as a property of the zone itself, so a landing zone can't add itself without changing the zone. Instead the `landing-zone` module creates a DNS peering zone in the landing zone's project that forwards the private zone names to `vpc-hub`. This needs `roles/dns.peer` for `sa-landingzones-apply` on `prj-platform-1307`, granted by `platform/gcp/connectivity`.
- **Not decided here:** a stamp's private endpoint writes its A record into the zone through a DNS zone group, which needs `Microsoft.Network/privateDnsZones/join/action` on the zone for `spn-lz-<lz>-deploy`. Who grants that, and on which zones, belongs with the stamp templates in `06-stamp-templates.md`. It is open question 7 in [`TODO.md`](../TODO.md#open-questions).
- **Spec:** `rg-platform-dns` is in [03 section 7.2](../03-naming-conventions.md#72-l1-platform-landing-zone) and `vnetl` in [03 section 5](../03-naming-conventions.md#5-resource-type-abbreviations); `private-dns.tf` in [04](../04-repository-structure.md) links the zones to the hubs only; the role and Reader grants are in the `spn-landingzones-apply` and `spn-landingzones-plan` rows in [02 section 6](../02-architecture.md#6-identity-and-access); [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 4 describes the links.
