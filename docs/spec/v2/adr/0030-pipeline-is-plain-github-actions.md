# ADR 0030: The pipeline is plain GitHub Actions workflows

> Part of [spec v2](../README.md).

- **Status:** proposed
- **Date:** 2026-09-28

## The problem

Every infrastructure change goes through the same steps: find out what the change touches, plan it, check it, get approval, apply it, merge. Tools exist that do this for OpenTofu inside a pull request, such as Digger or Atlantis. They are like a ready-made kitchen: quick to install, but built for a standard floor plan. Our floor plan isn't standard. A single PR can touch several layers that have to be applied in a fixed order, each with its own identity, and a stamp sometimes has to be applied twice in one PR.

Example: a PR adds the stamp `asg-con-prod` with the hostname `astra-group.example`. The pipeline must apply the stamp in `lz-cust-asg-prod-neu`, then `global/edge` in `global`, then the stamp again, with three separate approvals and three identities ([`08-pipeline.md`](../08-pipeline.md) section 6).

## The decision

The pipeline is a small set of plain GitHub Actions workflows in `tl-cloud-infrastructure`: `tofu-plan.yml`, `tofu-apply.yml`, `tofu-drift.yml` and the checks listed in [04](../04-repository-structure.md). A detect step maps changed paths to roots, and each root is planned and applied in its own job, in its own GitHub Environment. No separate orchestration tool is used.

## What this means in practice

- The whole pipeline is readable in the repository. There is no extra service to run, upgrade or pay for.
- Path to identity, layer order, the second stamp pass and the iTop gate are written once, in our own workflow code, and tested like any other change.
- Our own detect step and apply ordering need maintaining. They are kept small: a script that reads paths and prints a job list.

## Options we did not choose

| Option | Why not |
|---|---|
| Digger | Another component with its own configuration, lock handling and apply modes, which we would have to fit to apply-before-merge, per-landing-zone Environments and the second stamp pass. The layer order would still need our own logic around it |
| Atlantis | Needs a server that holds credentials for every layer, which breaks the per-layer identity split (N3) |
| A hosted service (Terraform Cloud, Spacelift, env0) | State and credentials leave our clouds, and it costs money per run or per user. The per-layer OIDC setup would have to be rebuilt in its model |

## Technical details

- **Detect step:** a script in `.github/scripts/` that takes the changed files of the PR and prints a JSON list of `{ root, key, layer, environment, plan_identity }`. The workflows turn it into a job matrix.
- **Reuse:** plan and apply are reusable workflows called once per root, so every layer runs the same steps.
- **Spec changes on acceptance:** none beyond [`08-pipeline.md`](../08-pipeline.md), which already assumes this decision.
