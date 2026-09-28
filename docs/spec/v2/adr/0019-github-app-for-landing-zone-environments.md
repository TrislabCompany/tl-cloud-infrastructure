# ADR 0019: A GitHub App creates each landing zone's GitHub Environment

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Every landing zone has its own GitHub Environment, `lz-<lz>`. Think of it as the locked room where the landing zone's key card is kept. The cloud hands out the key card (the deploy identity `spn-lz-<lz>-deploy`) only to pipeline jobs that run inside that room, and the room's door only opens once a named reviewer has approved the change. So the room and its lock have to exist, with the right reviewers, before the key card works.

The room lives in GitHub, not in Azure or GCP. The landing zone pipeline (`spn-landingzones-apply`) can create things in the cloud, but it has no credential for GitHub at all. So today it could make the key card but not the room. We have to decide what credential creates the room and removes it again when the landing zone is decommissioned.

Example: creating `cust-vbs-prod-sec` needs the Environment `lz-cust-vbs-prod-sec` with its required reviewers, plus the deploy identity's client ID stored in it, before the first stamp PR for `stamps/cust-vbs-prod-sec/` can be applied.

## The decision

A GitHub App, **`tl-landingzones-apply`**, installed only on `tl-cloud-infrastructure`, creates, updates and deletes the `lz-<lz>` Environments. Its private key is an Environment secret of `landingzones`, so only an approved landing zone apply can use it. A read-only GitHub App, **`tl-landingzones-plan`**, lets PR plans read the Environments. The `landing-zone` module creates the Environment in the same apply as the rest of the landing zone.

## What this means in practice

- A new landing zone is still one file and one PR. The stamp PRs that follow find their Environment ready.
- Decommissioning deletes the Environment in the same apply, as [02 section 3](../02-architecture.md#decommissioning) already describes.
- The Environment always has its required reviewers before the deploy identity trusts it. There is never a moment when the key card works but the door has no lock.
- Creating the two GitHub Apps is one more manual bootstrap step, done once by a GitHub organization owner, next to the billing step in [02 section 12](../02-architecture.md#12-bootstrap-manual-seed).
- The App key is a long-lived secret. It falls under the exception in N2 ([01](../01-requirements.md)), because GitHub has no way for a pipeline to manage Environments without one, and it is split into a plan and an apply credential as N2 requires. It is rotated by hand.
- The apply App can change any setting of `tl-cloud-infrastructure`, including the other Environments (`global`, `platform`, `landingzones`). Branch protection is set as organization rulesets, which it can't change. Its key is only reachable from an approved `landingzones` apply.

## Options we did not choose

| Option | Why not |
|---|---|
| Let GitHub create the Environment the first time a workflow uses it | GitHub creates it with no reviewers. Because the deploy identity trusts the Environment by name, anyone who can push a branch could run a job in `lz-<lz>` and get Contributor on the subscription |
| A separate `global/github` root creates every Environment from `landing-zones/*.yaml` | Every new or decommissioned landing zone would need a second PR in another layer. The Environment also needs the deploy identity's client ID from the landing zone's state, so it can only run after the landing zone apply |
| A platform engineer creates the Environment by hand | Against N11: only the seed is manual. Easy to forget the reviewers |
| A personal access token of a machine user | Tied to a user account, needs a seat, and expires. It can't be limited to one repository as cleanly as an App installation |
| The App key as a repository secret | Every workflow in the repository could read it, not only the approved `landingzones` apply |

## Technical details

- **App permissions** (repository permissions, installation on `tl-cloud-infrastructure` only):

  | App | Administration | Environments | Metadata |
  |---|---|---|---|
  | `tl-landingzones-apply` | Read and write: create and delete Environments, set reviewers | Read and write: Environment variables | Read |
  | `tl-landingzones-plan` | Read | Read | Read |

- **Where the keys live:** `tl-landingzones-apply`: App ID as an Environment variable and private key as an Environment secret of `landingzones`. `tl-landingzones-plan`: repository variable and repository secret, used by `pull_request` plan jobs. Pull requests from forks get no secrets.
- **What the module creates**, with the `integrations/github` provider, in this order:
  1. `github_repository_environment` `lz-<lz>` with required reviewers and `prevent_self_review`. No deployment branch policy, because apply runs from the PR branch before merge ([02 section 8](../02-architecture.md#8-delivery-flows)). The reviewers are what protect the Environment.
  2. Environment variables for the stamp pipeline: the deploy identity's client ID and the subscription ID (GCP: the Workload Identity provider and the service account e-mail).
  3. Only then the federated credential of `spn-lz-<lz>-deploy` for subject `environment:lz-<lz>`.

  On decommissioning the order is reversed: the federated credential and the identity go first, then the Environment.
- **Not decided here:** which GitHub team reviews each `lz-<lz>` (for example by archetype), and who creates the three layer Environments `global`, `platform` and `landingzones`. Both belong in `08-pipeline.md`.
- **Spec:** both App names are in [03 section 8](../03-naming-conventions.md#8-github-names); creating them is a step in [02 section 12](../02-architecture.md#12-bootstrap-manual-seed); the keys are in the secrets table in [02 section 6](../02-architecture.md#6-identity-and-access); [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 8 describes the Environment. GitHub App names are unique across all of GitHub, which is why they keep the `tl-` prefix like the repository names.
