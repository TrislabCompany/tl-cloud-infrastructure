# ADR 0031: Reviewers follow the landing zone's archetype, and the seed creates the layer Environments

> Part of [spec v2](../README.md).

- **Status:** proposed
- **Date:** 2026-09-28

## The problem

Every apply waits in a GitHub Environment until one of its reviewers approves it. The Environment is the locked door, and the reviewers hold the key. [ADR 0019](./0019-github-app-for-landing-zone-environments.md) decided how each landing zone's Environment `lz-<lz>` is created, but left two questions open: who holds the key for each door, and who builds the three doors of the layers themselves (`global`, `platform`, `landingzones`).

If every Environment has the same reviewers, a developer could approve changes to a regulated customer's production, or the platform team becomes a bottleneck for every sandbox change.

Example: a change to `stamps/cust-asg-sandbox-neu/construction-dev/` should be approvable by any Trislab engineer. The same change to `stamps/cust-vbs-prod-neu/construction/`, a regulated customer's production, should only be approvable by the restricted admin group ([F12](../01-requirements.md)).

## The decision

1. **Reviewers follow the archetype.** The `landing-zone` module sets each `lz-<lz>`'s reviewers from the landing zone's `archetype`:

   | Environment | Reviewers (GitHub team) |
   |---|---|
   | `lz-<lz>` with archetype `sandbox` | `devops` |
   | `lz-<lz>` with archetype `prod` | `platform-admins` |
   | `lz-<lz>` with archetype `prod-regulated` | `regulated-admins` |
   | `global`, `platform`, `landingzones` | `platform-admins` |

2. **The seed creates the layer Environments.** A GitHub organization owner creates `global`, `platform` and `landingzones` with their reviewers once, as part of the manual seed ([`09-bootstrap.md`](../09-bootstrap.md)).

## What this means in practice

- Sandbox changes move fast: any engineer in `devops` can approve them, but never their own.
- Production changes need a platform admin, and regulated production needs a regulated admin.
- The three GitHub teams mirror the Entra groups `grp-devops`, `grp-platform-admins` and `grp-regulated-admins` ([03 section 7.2](../03-naming-conventions.md#72-l1-platform-landing-zone)). Adding a person means adding them to both.
- The layer Environments never change in normal work. A change to their reviewers is a manual change by a repository admin.

## Options we did not choose

| Option | Why not |
|---|---|
| Reviewers declared per landing zone in `lz.yaml` | Every new landing zone would need a choice nobody wants to make, and a typo could leave a prod Environment with the wrong reviewers |
| The workload team that co-owns a stamp folder reviews its applies | CODEOWNERS already makes them review the PR. The apply approval is the platform's second pair of eyes |
| `platform/azure/identity` creates the layer Environments with the GitHub provider | `spn-platform-apply` would need a GitHub App key that can change every Environment, including its own. The first `platform` apply also needs the `platform` Environment to exist already |

## Technical details

- **Teams** are GitHub teams in the organization, synced from the Entra groups when the organization uses Entra ID for GitHub, or maintained by hand otherwise.
- **`prevent_self_review`** is on for every Environment.
- **Spec changes on acceptance:** add the three team names to [03 section 8](../03-naming-conventions.md#8-github-names), and add the reviewer rule to [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 8.
