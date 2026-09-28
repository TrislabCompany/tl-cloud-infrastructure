# ADR 0017: Availability zones are a setting per stamp

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

An Azure region is made of several separate datacentres, called **availability zones**. A service spread over zones keeps running if one datacentre fails, much like a shop with three entrances stays open when one door is blocked. Spreading costs more: more instances run, and some services charge extra.

Not every product needs this. A sandbox test environment can be down for an hour. A customer's production system may not.

Example: VBS Lawyers' production `construction` stamp `vbs-con-prod` must survive a datacentre failure, so its Container Apps environment `cae-vbs-con-prod` and its database `psql-vbs-con-prod-<nnnn>` run across zones. Its sandbox stamp `vbs-con-test` doesn't need to.

## The decision

Availability zones are **off by default** and can be turned on **per stamp** with `zone_redundant: true` in `stamp.yaml`.

## What this means in practice

- The owner of a product decides per stamp, based on its needs and budget.
- With the setting on, the stamp template uses the zone-redundant option of every service that has one.
- Turning it on or off later recreates the services that can't change in place, such as the Container Apps environment. Decide before the stamp goes live.

## Options we did not choose

| Option | Why not |
|---|---|
| Always on in production | Not every production product needs it, and it raises the cost of every production stamp |
| Never | Some customers need to survive a datacentre failure |
| One setting per service in the stamp | More choices than we need now. A per-service override can be added to the template later |

## Technical details

| Service | With `zone_redundant: true` |
|---|---|
| Container Apps environment | Zone-redundant environment (needs its own subnet, which every stamp has) |
| AKS | Node pools spread over zones 1, 2 and 3 |
| PostgreSQL flexible server (`db-postgres`) | High availability with the standby in another zone |
| Storage account | ZRS (zone-redundant storage) instead of LRS (locally redundant storage) |
| Neon, Upstash | No effect; these providers run outside our Azure subscriptions and have their own resilience |

- A CI check fails if `zone_redundant: true` is set and the landing zone's region has no availability zones. `northeurope`, `italynorth` and `swedencentral` all have zones.
- The field and its defaults are specified in `06-stamp-templates.md`. The example is in [`02-architecture.md`](../02-architecture.md) section 5.
