# ADR 0016: A region is added only when a product needs it

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Every region we use costs money and work even when it is empty: a hub network, a VPN gateway, private DNS zones, and policies to keep up to date. It is like opening a branch office in every city in advance, just in case a client appears there.

Example: VBS Lawyers may one day want `application-x` closer to its users in Sweden. Today no product runs there, so a Swedish hub would sit idle.

## The decision

We start with `northeurope`, with `italynorth` as the allowed secondary region. Another EU region is added **only when a product needs it**. It is fully set up and allowed before any landing zone uses it.

## What this means in practice

- A stamp can't be deployed to a region that is not on the allowed list. The policy blocks it.
- Adding a region is one planned piece of work, done in the order below, before the first landing zone in that region is created.
- Sweden (`swedencentral`) is not added now. It would get the code `sec` and the hub `vnet-hub-sec`.

## Options we did not choose

| Option | Why not |
|---|---|
| Add every likely region up front | Idle hubs and gateways cost money and need upkeep |
| Let a landing zone use any EU region without setup | The region would have no hub, no name code and no IP range, so the landing zone couldn't be built correctly |

## Technical details

Steps to add a region, in this order:

| # | Step | Where |
|---|---|---|
| 1 | Add the region to N6 | [`01-requirements.md`](../01-requirements.md) |
| 2 | Add its code, e.g. `sec` for `swedencentral` | [`03-naming-conventions.md`](../03-naming-conventions.md) section 3 |
| 3 | Add it to the `mg-root` allowed-locations policy and to `policy/regions.rego` | `platform/azure/governance`, `policy/` |
| 4 | Reserve a hub /20 from `10.0.0.0/12` | `catalog/ipam.yaml` |
| 5 | Create the hub, e.g. `rg-hub-sec`, `vnet-hub-sec` | `platform/azure/connectivity` |
| 6 | Create the landing zones that need it, e.g. `cust-vbs-prod-sec` ([ADR 0015](./0015-one-landing-zone-one-region.md)) | `landing-zones/` |

Before step 1, check that every service the stamp templates use is available in the region. A GCP region follows the same steps, as [ADR 0014](./0014-gcp-region-europe-west8.md) did for `europe-west8`.
