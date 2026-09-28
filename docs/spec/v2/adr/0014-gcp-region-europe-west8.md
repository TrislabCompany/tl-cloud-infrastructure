# ADR 0014: The first GCP region is `europe-west8` (Milan)

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

When the first GCP customer arrives ([ADR 0008](./0008-gcp-built-on-first-customer.md)), we need a Google Cloud region for the GCP hub and the customer's stamps. The region must be in the EU (N6). The closer it is to our users, the faster the applications respond.

Our team and most of our customers are in Slovenia. Google has no region in Slovenia, so we pick the nearest one.

## The decision

The first GCP region is **`europe-west8` (Milan)**, with the name token **`euw8`**, e.g. `vpc-hub` with subnet `snet-hub-euw8`.

## What this means in practice

- Milan is the Google region closest to Ljubljana, about 420 km away.
- Azure's secondary region `italynorth` is also in Milan, so both clouds are in the same city. A cross-cloud VPN between them stays short.
- Adding another GCP region later is a new hub, as on Azure.

## Options we did not choose

| Option | Why not |
|---|---|
| `europe-west3` (Frankfurt) | About 600 km away, farther than Milan |
| `europe-west12` (Turin) | About 560 km away and offers fewer services |
| `europe-west6` (Zurich) | Switzerland is not in the EU (N6) |

## Technical details

Distances are straight-line from Ljubljana. Before building, check that every service the `cloudrun-app` template uses is available in `europe-west8`. Region tokens: [`03-naming-conventions.md`](../03-naming-conventions.md) section 3. GCP hub: [`02-architecture.md`](../02-architecture.md) section 4.
