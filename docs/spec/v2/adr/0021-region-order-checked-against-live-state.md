# ADR 0021: Each region PR checks at plan time that the step before it is live

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Adding a region is like building a house: the building permit, then the foundation, then the walls, then the furniture. Each step needs the one before. Here that means allowing the region (PR 1), building its hub (PR 2), creating the landing zone (PR 3) and deploying the stamps (PR 4), in that order ([05 section 5](../05-landing-zones.md#5-adding-a-region)).

Today only one of these steps checks that its predecessor is done: a landing zone's plan fails if its region's hub doesn't exist. If the hub PR is applied before the region is allowed, its plan looks fine, and the apply then fails halfway when policy denies the first resource in the new region. We have to decide how the order is enforced, so that a PR in the wrong order fails at plan, before anything is created.

Example: someone opens the PR for `hub-sec.tf` while the PR that allows `swedencentral` is still waiting for approval. The hub PR should fail at plan with "region `swedencentral` is not allowed yet", not at apply.

## The decision

Each step checks, at plan time, that **the step directly before it is live in the cloud**, not only written in the repository. Because every step checks its own predecessor, the whole chain is enforced:

| PR | Checks at plan time that this is live | How |
|---|---|---|
| 2: build the hub | The region is in the `mg-root` allowed-locations policy assignment | Precondition in `connectivity` on a data source of the policy assignment |
| 3: create the landing zone | The region's hub exists | Data source `vnet-hub-<code>` in the `landing-zone` module (already in [05 section 3](../05-landing-zones.md#3-checks-before-apply)) |
| 4: create the stamps | The landing zone exists | The stamp job runs in the Environment `lz-<lz>`, which exists only after PR 3 ([ADR 0019](./0019-github-app-for-landing-zone-environments.md)) |

PR 1 has no predecessor in the cloud; the service check before it stays a manual checklist (open question 6).

## What this means in practice

- A PR in the wrong order fails at plan, with a message that names the missing step. Nothing is created, and the PR is simply re-planned once the step before it is applied.
- The check can't be skipped by putting the earlier step's files into the same PR, because it reads the cloud, not the branch.
- People can still open all the PRs at once and review them in parallel. Only the applies have to happen in order.
- The pipeline needs no knowledge of the order. Each root checks only what it depends on.
- Policy changes take time to reach Azure. PR 2's plan can pass as soon as the assignment is updated, while the apply is still denied for a few minutes. The first resource created is `rg-hub-<code>`, so a denied apply creates nothing, and a re-run after a short wait succeeds.

## Options we did not choose

| Option | Why not |
|---|---|
| Convention only, as today | The hub PR before the region PR fails at apply, not at plan. Easy to get wrong with several PRs open |
| A plan-time OPA rule that the region is in `policy/regions.rego` and has a hub in `catalog/ipam.yaml` | Checks files, not what is live. A PR that includes the earlier step's file changes passes, even though that step was never applied |
| One PR that the pipeline applies root by root, in a fixed order | One PR would need three Environments, three approvals and three identities in sequence, with a wait for policy propagation in the middle. A failure in the middle leaves the PR half-applied. Adding a region happens rarely, so the extra pipeline logic isn't worth it |
| Branch protection that requires every PR to be up to date with `main` | Only ensures the earlier PR's *files* are on the branch, not that its apply succeeded. It also forces a rebase of every open PR after each merge |

## Technical details

- **PR 2 check** in `platform/azure/connectivity`, in each `hub-<code>.tf`:
  - an `azurerm_management_group_policy_assignment` data source for the allowed-locations assignment on `mg-root`;
  - a `precondition` on `rg-hub-<code>` that the hub's region is in the assignment's `listOfAllowedLocations` parameter, with the message "region `<region>` is not allowed yet: apply the governance PR first".
- **Rights:** `spn-platform-plan` already reads `mg-root`, because it plans `platform/azure/governance`. No new role assignment is needed.
- **PR 3 and PR 4:** no change. The hub data source and the Environment already exist as checks.
- **GCP:** the same in `platform/gcp/connectivity`, with a precondition on the effective `gcp.resourceLocations` organization policy.
- **Spec:** [05 section 3](../05-landing-zones.md#3-checks-before-apply) lists the PR 2 check; [05 section 5](../05-landing-zones.md#5-adding-a-region) refers to this ADR for the order.
