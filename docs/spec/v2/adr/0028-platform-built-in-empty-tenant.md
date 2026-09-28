# ADR 0028: The platform is built in an empty tenant; nothing is adopted

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Trislab's Azure tenant and GCP organization already hold a few resources: a management group, a subscription, a Key Vault, a state backend, two pipeline identities and a GCP bucket. They were made before this specification and don't follow its names, hierarchy or layers. Think of a plot with an old shed on it. We can move the shed and fit it into the new house, or clear the plot and build the house as drawn.

Keeping them means renaming or importing each one. Many can't be renamed at all: a management group ID, a storage account name and a subscription alias are fixed when they are created. They would be recreated anyway, just with more steps and more risk. None of them holds data or traffic that anyone depends on.

Example: the subscription `sub-tl-shared-infra-azure` could be moved to `mg-platform` and given the display name `sub-platform`, but its alias would stay `sub-tl-shared-infra-azure`. That breaks principle 9 in [03](../03-naming-conventions.md#1-principles), and every later reader would wonder why this one name is different.

## The decision

The platform is built from the manual seed ([`09-bootstrap.md`](../09-bootstrap.md)) in an empty tenant and organization. Every existing resource is removed, not imported, renamed or reused. The platform gets a new subscription `sub-platform`, and the existing subscription is cancelled once it is empty.

## What this means in practice

- The first roadmap phase clears the tenant ([`10-roadmap.md`](../10-roadmap.md) section 3). The seed starts only after that.
- Every name in the tenant follows [03](../03-naming-conventions.md) from the first day. There are no exceptions to explain.
- No state is carried over. The platform roots start with empty state and adopt only what the seed creates.
- The OpenTofu roots, workflows and documents in `tl-cloud-infrastructure` that build the removed resources are deleted from the repository in the same phase.
- Nothing runs on the removed resources, so no service is interrupted.

## Options we did not choose

| Option | Why not |
|---|---|
| Import the resources into the new roots with `import` and `moved` blocks | The management group IDs, the storage account and the subscription alias can't be renamed, so they would be recreated anyway. Importing the rest means mapping every resource to its new root first, for resources that hold nothing we need |
| Reuse the subscription as `sub-platform` | Its alias can't change, which breaks principle 9 in 03. A new subscription costs nothing |
| Build the platform next to the existing resources and remove them later | Two management group trees and two sets of pipeline identities in one tenant for a while, and the same workflow file names in one repository. Harder to review, and nothing is gained |

## Technical details

- **What is removed**, in this order:

  | # | What | How |
  |---|---|---|
  | 1 | The workflows `tofu-plan.yml`, `tofu-apply.yml`, `tofu-drift.yml` and `prowler-iac-scan.yml`, and their required status checks in branch protection | Disable the workflows, then remove the checks, so no PR is blocked and no run touches the cloud |
  | 2 | Everything in the roots `shared-infrastructure/azure` and `shared-infrastructure/gcp`: role assignments, the Key Vault `kv-tl-shared-infra` and its secret, the budget `budget-tl-shared-infra-azure`, the action group, `rg-tl-shared-infra-governance`, the allowed-locations assignment, and the management groups `mg-tl`, `mg-tl-shared-infra`, `mg-tl-products`, `mg-tl-customers` | `tofu destroy` run locally by a PIM-activated tenant owner, because the pipeline identities are removed in step 3. The subscription is moved back to the Tenant Root Group first, so the management groups are empty |
  | 3 | The app registrations `spn-tl-github-sharedinfra-azure-plan` and `-apply` with their federated credentials, and the group `Trislab-DevOps` | Entra ID, by hand |
  | 4 | The state backend `rg-tl-shared-infra-state` with `sttlsharedinfra` | After step 2, when the state is empty. Deleted by hand |
  | 5 | GCP: the service accounts `sa-tl-github-sharedinfra-plan` and `-apply`, the pool `tl-github-pool`, the bucket `tl-shared-infra-tofu-state-backup` and the project that holds them | By a GCP organization admin. A deleted project ID can never be used again, which doesn't matter because the new project has a different ID |
  | 6 | The subscription `sub-tl-shared-infra-azure` | Cancelled by a billing account owner once it is empty. Azure keeps it disabled for about 90 days, then deletes it |
  | 7 | The GitHub Environments `production` and `azure-gcp-plan`, and the repository variables `AZURE_*` and `GCP_*` and the secret `INFRACOST_API_KEY` | By a repository admin. The new pipeline brings its own ([`08-pipeline.md`](../08-pipeline.md)) |
  | 8 | The folder `shared-infrastructure/`, the old workflows, and the documents under `docs/` outside `docs/spec/v2/` | One PR |

- **Soft delete.** `kv-tl-shared-infra` has purge protection, so it stays soft-deleted for 90 days. Its name doesn't clash with any name in 03, so nothing waits for it.
- **Billing.** The invoice section that `sub-tl-shared-infra-azure` was billed to is renamed to `is-platform` and keeps its old invoices ([ADR 0011](./0011-one-invoice-with-a-section-per-owner.md)). `sub-platform` is created in it.
- **Check before step 2:** list the resources in the subscription and in the GCP project, and confirm that nothing exists outside the two roots' state.
