# ADR 0013: Sandbox and production are separated by NSG rules, without Network Manager

- **Status:** superseded by [0025](./0025-stamp-nsg-carries-isolation-rules.md)
- **Date:** 2026-09-28

## The problem

Sandbox and production networks must never talk to each other (N4). Azure offers two ways to enforce that. The first is a rule on each network, like a lock on every door. The second is Azure Virtual Network Manager, a central service that pushes the same rules to all networks at once, like a security desk for the whole building.

A central desk pays off when there are many doors. We will have a small number of landing zones for a long time, and each one is created by the same module.

## The decision

Each spoke gets **NSG rules** that deny all sandbox ↔ production traffic. The `landing-zone` module creates them. **Azure Virtual Network Manager is not used.**

## What this means in practice

- Every landing zone gets the same rules, because one module writes them all.
- No extra service to pay for or run.
- If the number of spokes ever makes the rules hard to keep consistent, a new ADR revisits this.

## Options we did not choose

| Option | Why not |
|---|---|
| Network Manager from day one | A per-subscription charge and one more service to run, with no benefit at our number of spokes |
| Introduce Network Manager at a fixed number of spokes (e.g. 10) | A number picked in advance; we would rather decide from real experience |

## Technical details

Isolation rules: [`02-architecture.md`](../02-architecture.md) section 4. The rules are part of the `landing-zone` module, specified in `05-landing-zones.md` (see [`TODO.md`](../TODO.md)).
