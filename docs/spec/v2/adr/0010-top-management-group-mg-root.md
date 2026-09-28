# ADR 0010: The top management group is `mg-root`

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

All of Trislab's Azure subscriptions hang below one top-level management group, where company-wide rules live (EU regions only, mandatory tags). It used to be called `mg-tl`. With the company token removed from names ([ADR 0001](./0001-no-company-token-in-names.md)), it needs a new name.

## The decision

The top management group is **`mg-root`**, with the display name "Trislab". Everything else sits below it: `mg-platform`, `mg-landingzones`, `mg-experiments`, `mg-decommissioned`. On GCP, the organization itself is the top, so no extra folder is needed.

## What this means in practice

- The name says what the group is: the root of our hierarchy.
- The Azure portal still shows "Trislab" as the display name.

## Options we did not choose

| Option | Why not |
|---|---|
| `mg-org` | Less obvious that it's the top of the tree |
| Keep `mg-tl` as the only exception | Breaks the rule from ADR 0001 for no real benefit |

## Technical details

`mg-root` sits below Azure's built-in "Tenant Root Group". Company-wide policies are assigned at `mg-root`, never at the Tenant Root Group. See [`02-architecture.md`](../02-architecture.md) section 2.
