---
name: stamp-destroy
description: Destroy a stamp in tl-cloud-infrastructure — after its data is exported, delete its folder stamps/<lz>/<folder>, its /27 in catalog/ipam.yaml and its tenant and hostnames in catalog/tenants.yaml — as one PR opened with the user's own gh credentials; the pipeline plans the destroy, and global deletes its DNS records, Access applications and the app repository's Environment. Use when the user asks to destroy, delete, remove, deprovision, tear down or shut down a stamp or an app environment such as dev, staging, demo or prod.
metadata:
  owner: infrastructure
---

# stamp-destroy

One PR. On apply:
- the stamp is destroyed with its landing zone's deploy identity, planned with `-destroy` from `main`'s copy;
- `global/edge` deletes its records and Access applications;
- `global/github` deletes the app repository's Environment and takes it out of `SIZING_CAPS`.

The stamp's secrets stay in the Key Vault's soft delete for 90 days, and a stamp created again with the same code recovers them. The /27 is free once the destroy is applied.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required |
| --- | --- |
| `stamp`, as `<lz>/<folder>` or its stamp code (`shr-web-dev`) | yes |
| `export` | yes: where the data that anyone needs was exported, or "none, and why" |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)).
2. **Read the stamp:**
   - `stamps/<lz>/<folder>/stamp.yaml`;
   - its range in `catalog/ipam.yaml`;
   - its tenants in `catalog/tenants.yaml`;
   - the deployments it runs: `gh api "repos/TrislabCompany/<repo>/deployments?environment=<environment>&per_page=1" --jq '.[0].ref'`.
3. **Warnings,** each needing an explicit yes:
   - **Custom hostnames:** a tenant hostname that isn't the default `<env>-<product>…trislab.com` (for example `trislab.com`) stops answering. Ask whether it should move to another stamp first: [`hostname-create`](../hostname-create/SKILL.md) on the new stamp.
   - **Prod:** a `prod` stamp, or one in a `-prod-` landing zone, is destroyed only after the user names the stamp code again.
   - **No data export:** without an `export` answer, stop.
4. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)).
5. **Write**, on branch `destroy-<lz>-<folder>`:
   - `git rm -r stamps/<lz>/<folder>`;
   - **`catalog/ipam.yaml`:** delete `<folder>: <range>` under the landing zone. If it was the only stamp, delete the then-empty `stamps:` key too;
   - **`catalog/tenants.yaml`:** delete every tenant entry with `stamp: <lz>/<folder>`.
6. **Check and open the PR** ([shared steps 4 and 5](../_shared/pr.md#4-check)).
   - **Title:** "Destroy the stamp <stamp code> (<lz>/<folder>)".
   - **Body:**
     - the data export answer;
     - the hostnames that stop answering;
     - "the plan must show only destroys in `rg-<stamp code>`".
7. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)). If the landing zone now has no stamps and is meant to go too, point to [`landing-zone-decommission`](../landing-zone-decommission/SKILL.md).
