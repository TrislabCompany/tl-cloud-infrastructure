# tl-cloud-infrastructure

> The live infrastructure of the Trislab platform: the platform's own Azure resources, the landing zones, the stamps and the edge, each described by files here and applied by the pipeline from a PR. The modules and stamp templates it pins live in `tl-platform`.

This file is the guide for every AI coding tool (Claude Code, Cursor, Codex, …). `CLAUDE.md` only imports it: edit the conventions here. The platform spec (`docs/spec/v2/`) is git-ignored and is not in a fresh clone, so this file and the skills carry the rules they need. Where the spec is named, ask a member of `devops` for it when you don't have the local copy.

## Repository map

| Path | What | Layer, Environment |
| --- | --- | --- |
| `platform/azure/<root>/` | The platform's own resources: `state`, `governance` (management groups, policy, the allowed regions), `identity` (groups, including `grp-cust-<code>-admins` of every active client tenant, and pipeline identities), `management`, `connectivity` (one `hub-<code>.tf` per region) | `platform`, Environment `platform` |
| `landing-zones/<lz>.yaml` | One file per landing zone. `landing-zones/_root/` calls the `tl-platform` module `landing-zone` once per file, with the file name as the state key | `landingzones`, Environment `landingzones` |
| `stamps/<lz>/<folder>/` | One stamp: `stamp.yaml`, a generated `main.tf` and `.terraform.lock.hcl`, nothing else | `stamps`, Environment `lz-<lz>` |
| `global/edge/` | Cloudflare: zones, the stamps' DNS records, origin certificates, Access applications, redirects, and the Pages projects of the products with `environments` in `catalog/products.yaml` with their hostnames, records and Access applications. `global/edge/records/<zone>/*.yaml` holds the records that are not stamps (mail, verification, sites outside the platform) | `global`, Environment `global` |
| `global/github/` | The app repositories (one per product), their GitHub teams `<tenant>-<product>`, Environments and variables, from `catalog/products.yaml`; for a Pages site also its Cloudflare deploy token, written as the Environments' secret, and its release tag ruleset | `global`, Environment `global` |
| `catalog/` | `regions.yaml`, `ipam.yaml`, `products.yaml` (tenants and their products), `domains.yaml` (domains and `stamp_tenants`), `cloudflare-ips.yaml`: the registers every layer reads | Whichever roots read the changed entry |
| `policy/` | The rego rules the PR's plan runs (`catalog`, `naming`, `regions`, `tags`, `trusted-code`) and their unit tests | — |
| `.github/workflows/`, `.github/scripts/` | The pipeline: plan on every PR, `/apply`, drift, stamp check | — |
| `.agents/skills/` | The skills below; the only place skills are written. `.agents/skills/_shared/` holds the steps and scripts every skill uses | — |
| `.claude/skills/` | One pointer per skill, with the same front matter, so that Claude Code lists it | — |

## How a change is applied

- **Every change is a PR** to `main`. The PR's plan runs for each root it touches and posts the plan. The required checks are `plan`, `conftest`, `prowler`, `stamp-check` and `applied`.
- **Apply before merge.** On an approved PR from a branch of this repository, a writer comments `/apply`. The roots are applied layer by layer, each in its Environment. A `devops` member approves each run, and nobody approves their own. When every root is applied, `applied` turns green and the workflow merges the PR.
- **Layer order:**
  1. `platform` (`state` → `governance` → `identity` → `management` → `connectivity`)
  2. `landingzones`
  3. `stamps`
  4. `global` (`edge` → `github`)
  5. `stamps` again, to bind hostnames once `global` has written their records and certificates.
- **One step per PR when an order is needed.** A landing zone comes in one PR and its stamps in a second, because a stamp needs the Environment `lz-<lz>` that the landing zone's apply creates. A PR that depends on another says `Depends on #<n>` in its description, and is re-planned automatically when that one is applied.
- **Rebase before `/apply`** when `main` has changed the PR's roots since its plan. After a rebase, `git diff --stat origin/main...HEAD` lists only the PR's own files; rebuild the branch rather than keep a commit that takes out what another PR now owns ([`_shared/pr.md`](.agents/skills/_shared/pr.md#update-a-pr)).
- **Removing a root** (a stamp folder, a landing zone file) is planned with `-destroy` from `main`'s copy.

## Rules

- **The skills write the files and open the PR.** They use the signed-in user's own `gh` and `az`. They never approve, `/apply` or merge: that is a second person in `devops`, by design.
- **Nothing is applied by hand.** No `tofu apply`, `az … create/delete` or portal changes. `az` is used only to read.
- **Workflow changes go in their own PR.** A PR that touches `.github/**` together with a root fails.
- **Generated files are never hand-edited.** A stamp's `main.tf` comes from `tl-platform/stamps/<template>/generate.ps1` at the template's pinned tag.
- **Registers keep their entries.** No entry is removed from `products.yaml` or `regions.yaml`: a tenant and a region are retired (`state: retired`), a product and its repository are archived (`state: archived`). Owner codes, region codes and `-<nn>` numbers are never reused.
- **Ranges.** A range is reserved by being in `catalog/ipam.yaml`, and freed when its entry is deleted. The pools never change without an ADR.
- **No AI attribution.** No `Co-Authored-By:` trailer and no "generated with" line in a commit, PR title or description.
- **The repository is public.** No secrets, no personal data (group members are added by hand in Entra ID), no client contracts or prices.

## Lifecycle verbs

Use these verbs and only these, in files, commits, PRs and answers (spec 03 section 12):

| Object | Start | End |
| --- | --- | --- |
| Region (with its hub) | register | retire (`state: retired`) |
| Landing zone | create | decommission, then cancel (`active` → `decommissioned` → `cancelled`) |
| Subscription | create | cancel |
| Stamp | create | destroy (its folder is deleted) |
| Hostname, DNS record, Environment | create | delete |
| Customer, product (the whole process) | onboard | offboard |
| App repository | create | archive |

*Provision*, *deprovision* and *tear down* are not used. A landing zone is never *retired*, and a stamp is never *removed*.

## Address plan

| Pool | Range | Takes |
| --- | --- | --- |
| Hubs | `10.0.0.0/12`: Azure from `10.0.0.0/13`, GCP from `10.8.0.0/13` | One /20 per region's hub, the next free one in its cloud's half. The hub's `GatewaySubnet` is the /27 at its start |
| Prod | `10.16.0.0/12` | One /20 per prod landing zone, the next free one |
| Sandbox | `10.32.0.0/12` | One /20 per sandbox landing zone, the next free one |
| Stamp | Inside its landing zone's /20 | The lowest free block aligned to its size: a /27 when every app is `Consumption` |

`python .agents/skills/_shared/ipam.py` computes each of these from `catalog/ipam.yaml`.

## Names

| Thing | Form | Example |
| --- | --- | --- |
| Region code | 2–4 lowercase letters and digits, unique across both clouds, not a reserved token | `neu`, `itn`, `euw8` |
| Hub | `vnet-hub-<code>` (Azure), `snet-hub-<code>` (GCP), in `rg-hub-<code>` | `vnet-hub-neu` |
| Landing zone | `<scope>-<envtype>-<region code>[-<nn>]`, where `<scope>` is `products`, `cust-<code>` or `prdt-<code>` and `<envtype>` is `prod` or `sandbox`. `-<nn>` starts at `02` | `products-prod-neu` |
| Experiment landing zone | `exp-<topic>` | `exp-test` |
| Subscription | `sub-<lz>` | `sub-products-prod-neu` |
| Stamp folder | `<product>-<environment>`, `<product>` alone in prod | `corporate-site-dev`, `corporate-site` |
| Stamp code | `<owner code>-<product code>-<environment>[-<nn>]`, where `<owner code>` is `shr` in `products-*` | `shr-web-prod` |
| Default hostname | `<environment>-<product>[-<customer>][-<nn>].trislab.com`, one label below `trislab.com` | `prod-corporate-site.trislab.com` |

Reserved tokens, never a code: `root platform landingzones lz products cust prdt shr prod sandbox sb dev test uat perf demo staging experiment exp global standard regulated experiments decommissioned`.

## Checks before a PR

Run the ones that are installed. The PR's plan runs all of them anyway.

```bash
tofu fmt -check -recursive
python .agents/skills/_shared/check-catalog.py       # the catalog rules, as the plan runs them (needs conftest)
conftest verify --policy policy                       # when policy/ changed (needs conftest)
tofu -chdir=<root> init -backend=false && tofu -chdir=<root> validate   # each changed .tf root
```

## Skills

Skills live only in `.agents/skills/<name>/SKILL.md`. When a task matches a skill, read that file and follow it. Claude Code finds skills only in `.claude/skills/`, so each skill also has a pointer `.claude/skills/<name>/SKILL.md`, with the same front matter and a body that sends the agent to the real file. Add one with every new skill. Every skill follows [the shared steps](.agents/skills/_shared/pr.md) and ends with an open PR.

| Skill | Use when |
| --- | --- |
| [`infra-status`](.agents/skills/infra-status/SKILL.md) | Asking what exists: regions, hubs, landing zones, stamps, hostnames, free ranges, open infrastructure PRs. Reads only |
| [`region-register`](.agents/skills/region-register/SKILL.md) | Allowing a new region and building its hub, or building the hub of a region that is registered without one |
| [`region-retire`](.agents/skills/region-retire/SKILL.md) | Deleting a region's hub and retiring the region, once no landing zone uses it |
| [`landing-zone-create`](.agents/skills/landing-zone-create/SKILL.md) | Creating a landing zone (prod, sandbox or experiment) in a region with a hub |
| [`landing-zone-decommission`](.agents/skills/landing-zone-decommission/SKILL.md) | Decommissioning a landing zone with a hold, once its stamps are destroyed |
| [`landing-zone-cancel`](.agents/skills/landing-zone-cancel/SKILL.md) | Cancelling a landing zone after its hold or without one, and the clean-up PR after Azure has deleted the subscription |
| [`stamp-create`](.agents/skills/stamp-create/SKILL.md) | Creating a stamp, with its range, its tenant and its default hostname |
| [`stamp-destroy`](.agents/skills/stamp-destroy/SKILL.md) | Destroying a stamp: its folder, range and tenant |
| [`hostname-create`](.agents/skills/hostname-create/SKILL.md) | Adding a custom hostname to a stamp, including moving a domain's apex from an outside host to a stamp |
| [`hostname-delete`](.agents/skills/hostname-delete/SKILL.md) | Deleting a custom hostname from a stamp |
