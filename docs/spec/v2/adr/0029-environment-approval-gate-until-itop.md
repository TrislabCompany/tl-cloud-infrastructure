# ADR 0029: The GitHub Environment approval is the only apply gate until iTop runs

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

N1 in [01](../01-requirements.md) says a production or platform apply needs an approved iTop Change Request, next to the reviewer's approval. iTop is the ticket system where a change is written down and signed off. But iTop is itself a platform app ([F13](../01-requirements.md)), and it runs on the platform the pipeline is building. It's like a building permit office inside the building that needs the permit: it can't stamp anything until it is built.

Example: the first `platform` apply creates the management groups. At that moment there is no iTop, so a pipeline that insists on a Change Request could never apply anything, including iTop itself.

## The decision

Until iTop's production instance runs, the GitHub Environment approval is the only gate for applies, in every Environment. The pipeline turns on the iTop Change Request check for every production and platform apply ([`08-pipeline.md`](../08-pipeline.md) section 5 lists them) in the roadmap phase that builds iTop ([`10-roadmap.md`](../10-roadmap.md)). From then on, N1 holds in full.

## What this means in practice

- Every apply before that phase still needs a named reviewer's approval in its GitHub Environment, and every change is still a reviewed PR with a plan, cost estimate and scans.
- The PR itself, with its plan comment and approval, is the record of each change until iTop exists.
- Only the pilots run in prod during that time, so the gap covers no customer production data except the Astra Group pilot's.
- Turning the check on means setting one repository variable. Nothing else in the design changes.

## Options we did not choose

| Option | Why not |
|---|---|
| Build iTop first, before the platform landing zone | iTop needs a container platform, a database and Zero Trust access, which are the platform itself. Building it first means building a second, temporary platform |
| Use a different ticket system until iTop runs | A second change process to set up, learn and then retire, for a few months |
| Block prod applies until iTop runs | Nothing in prod, including the pilots, could be proven before the last phases |

## Technical details

- **Switch.** A repository variable `ITOP_GATE` (`off` or `on`) is read by `tofu-plan.yml` and `tofu-apply.yml`. With `off`, the jobs skip opening and checking the Change Request ([`08-pipeline.md`](../08-pipeline.md) section 5). Only a repository admin can change it.
- **Sandbox** Environments never need a Change Request, before or after, as N1 covers only production and platform.
