# ADR 0007: A customer's dev and test share one sandbox landing zone

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

A dedicated customer gets dev, test and prod environments. Each landing zone is a separate Azure subscription with its own budget, network, key safe and access rules. We have to decide whether dev and test each get their own landing zone, or share one.

It's like renting office space. Production gets its own locked building. Dev and test are two rooms in a second building: separate rooms with their own doors, but one lease, one alarm system and one bill.

## The decision

Each customer has **two** landing zones: `cust-<code>-prod` and `cust-<code>-sandbox`. Dev and test are separate stamps inside the sandbox landing zone, each with its own network segment and firewall rules.

## What this means in practice

- Half as many subscriptions, budgets and access setups per customer.
- Dev and test are still separated from each other at the network level.
- Production is always fully separated from dev and test.

## Options we did not choose

| Option | Why not |
|---|---|
| One landing zone per environment (dev, test, prod) | Triples the setup and cost overhead per customer for little extra safety |
| One landing zone for everything | Mixing production with test breaks the isolation requirement (N4) |

## Technical details

[`02-architecture.md`](../02-architecture.md) section 2 (collapse and growth) and section 4 (network isolation).
