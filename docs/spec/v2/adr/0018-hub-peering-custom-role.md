# ADR 0018: The landing zone pipeline may only add and remove peerings on the hub

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

A peering is like a door between two neighbouring flats. It only opens if both neighbours fit a door on their own side of the wall. The landing zone's network (the spoke) is one flat; the region's hub network is the other. When we create a landing zone, we fit the spoke's door and the hub's door in the same step.

The trouble is who holds the keys. The hub belongs to the platform team, and the pipeline that creates landing zones (`spn-landingzones-apply`) has no rights there at all. So today it could fit the spoke's door but not the hub's, and the landing zone would have no working connection. We have to decide how the hub's side gets done without handing the landing zone pipeline the keys to the whole hub.

Example: creating `cust-vbs-prod-sec` in Sweden needs a peering from `vnet-cust-vbs-prod-sec` to `vnet-hub-sec` **and** one from `vnet-hub-sec` back to the spoke. The second one lives in the platform connectivity subscription.

## The decision

A custom role, **"Landing zone hub peering"**, allows only reading the hub and adding, changing and removing its peerings. The `connectivity` root assigns this role to `spn-landingzones-apply` on each hub VNet when it builds the hub. The `landing-zone` module then creates and removes both halves of its own peering in the same apply.

## What this means in practice

- A new landing zone is still one file and one PR. No platform PR is needed to connect it to the hub.
- Decommissioning removes both halves of the peering in the same apply, as [02 section 3](../02-architecture.md#decommissioning) already describes.
- The landing zone pipeline can't change the hub's address range, subnets, VPN gateway or DNS, and can't delete the hub.
- It can add or remove *any* peering on the hub, including another landing zone's. Plan review, the plan comment on the PR and nightly drift detection are what catch a wrong change.
- Building a hub (PR 2 in [05 section 5](../05-landing-zones.md#5-adding-a-region)) now also grants this role. A landing zone PR in a region whose hub was built without it fails at plan, not halfway through apply.
- `spn-landingzones-plan` gets Reader on each hub VNet too, so the plan can read the hub and show the hub half of the peering.

## Options we did not choose

| Option | Why not |
|---|---|
| Network Contributor on each hub VNet | Also allows changing the hub's address range and subnets, the `GatewaySubnet`, and deleting the hub. One wrong landing zone PR could cut every landing zone in the region off |
| Network Contributor or Owner on the whole connectivity subscription | Even broader: every hub, the VPN gateways and the private DNS zones |
| The `connectivity` root creates the hub half by reading `landing-zones/*.yaml` | Every new or decommissioned landing zone would need a second PR in the `platform` layer. Between the two applies the peering sits half-open ("Initiated") and carries no traffic. It breaks "a new landing zone is one file" |
| Run the hub half with `spn-platform-apply` inside the landing zone job | One job would hold two layers' identities, against the rule that the folder decides the identity ([ADR 0006](./0006-monorepo-with-path-based-identity.md)) |
| Azure Virtual Network Manager hub-and-spoke connectivity | We don't use Network Manager ([ADR 0013](./0013-nsg-rules-without-network-manager.md)) |

## Technical details

- **Role actions:**

  | Action | Why |
  |---|---|
  | `Microsoft.Network/virtualNetworks/read` | Data source for the hub; read the peering state |
  | `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read`, `/write`, `/delete` | Create, update and remove the hub half |
  | `Microsoft.Network/virtualNetworks/peer/action` | Needed on the remote VNet when the spoke half is created, because the hub is the remote side |

- **Where it is defined and when it is assigned:** everything is in `platform/azure/connectivity`, applied by `spn-platform-apply` (Owner on `mg-platform`, which includes creating role definitions and assignments). There is no manual step.

  | What | File | When |
  |---|---|---|
  | Role definition "Landing zone hub peering". Assignable scope: the platform connectivity subscription (`sub-platform` in the MVP) | `peering-role.tf` | Once, in the same apply that builds the first hub (`hub-neu.tf`). It changes later only if its actions change |
  | This role for `spn-landingzones-apply`, on `vnet-hub-<code>` | `hub-<code>.tf`, next to the VNet | In the same apply that creates the hub: PR 2 in [05 section 5](../05-landing-zones.md#5-adding-a-region) for a new region |
  | Reader for `spn-landingzones-plan`, on `vnet-hub-<code>` | `hub-<code>.tf` | Same apply |

  The role is only ever granted on a hub that exists, never on the whole subscription. It lives in `connectivity` rather than `identity` because the assignment needs the hub VNet's ID, which only `connectivity` has. The role has a display name only; [03](../03-naming-conventions.md) has no naming rule for role definitions.
- **Order and dependencies:**
  1. `platform/azure/identity` creates `spn-landingzones-apply` and `spn-landingzones-plan`.
  2. `platform/azure/connectivity` reads both identities' object IDs with an `azuread_service_principal` data source. If they don't exist yet, its plan fails, so `identity` is applied first.
  3. `landing-zones/_root` creates both halves of the peering. If the assignments are missing, its plan fails at the hub data source, before anything is created.
  4. New role assignments can take a few minutes to take effect. If the landing zone plan fails on permissions right after the hub PR is applied, re-run it.
- **Module:** the `landing-zone` module uses a second `azurerm` provider alias pointed at the connectivity subscription for the hub half. The hub half's settings (e.g. `allow_forwarded_traffic`, `allow_gateway_transit` when the hub has a VPN gateway) are fixed in the module and not set in `lz.yaml`.
- **Limit:** Azure role assignment conditions can't limit peering writes by name or by remote VNet, so the role can't be narrowed to "only this landing zone's peering".
- **Spec:** the `spn-landingzones-apply` and `spn-landingzones-plan` rows in [02 section 6](../02-architecture.md#6-identity-and-access) list the hub VNet scopes; [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 4 and section 5 PR 2 describe the peering and the assignments.
- **GCP:** the same idea with a custom role holding `compute.networks.get`, `compute.networks.addPeering`, `compute.networks.updatePeering` and `compute.networks.removePeering`, granted to `sa-landingzones-apply` on `prj-platform-1307` by `platform/gcp/connectivity`. The broader `roles/compute.networkAdmin` is not used. On GCP the role is granted on the project, because IAM can't be set on a single VPC.
