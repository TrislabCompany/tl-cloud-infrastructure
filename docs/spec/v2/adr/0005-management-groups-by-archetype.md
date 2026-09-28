# ADR 0005: Management groups follow the type of environment, not the customer

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

In Azure, subscriptions (the containers that hold resources and bills) are organised in a tree of **management groups**. Rules (policies) attached to a group apply to everything below it. We need to decide how to shape this tree.

One option is a branch per customer. That's like a school giving every pupil their own rulebook: it's fine with five pupils and unmanageable with two hundred, and the rules mostly repeat. What actually differs between groups is the *kind* of environment: production needs strict rules, sandboxes need cost caps, regulated customers need extra auditing.

## The decision

Management groups are organised by **type of environment**: `mg-lz-prod`, `mg-lz-sandbox`, and `mg-lz-prod-regulated` for customers with legal or compliance needs. There is **no management group per customer**. Each customer gets their own subscriptions, and the subscription is their isolation boundary.

## What this means in practice

- Adding a customer adds subscriptions, never new branches or new rule sets.
- A rule change for "all production" is made once and applies everywhere.
- If one customer ever needs a special rule, a small child group is added under the right type, only then.

## Options we did not choose

| Option | Why not |
|---|---|
| One management group per customer | Duplicated policies, and the tree grows with every customer |
| Group by product | Products and customers overlap; environment type is what drives the rules |

## Technical details

Hierarchy and policy-by-scope table: [`02-architecture.md`](../02-architecture.md) section 2.
