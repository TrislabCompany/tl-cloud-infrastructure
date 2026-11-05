---
name: infra-status
description: Show what exists in tl-cloud-infrastructure, read-only — the regions and their hubs, landing zones with their state, range and hold, stamps with their environment, version, range and hostnames, the next free ranges, and the open infrastructure PRs with their plan and apply status. Changes nothing and opens no PR. Use when the user asks what exists, what runs where, which landing zones or stamps there are, which ranges are free, or the status of an infrastructure PR.
metadata:
  owner: infrastructure
---

# infra-status

Reads the catalog on `origin/main` and the open PRs, and prints a short report. It writes nothing, opens no PR and needs no yes. `az` is optional: the live checks are skipped without it.

## Steps

1. `git fetch origin --prune`. Read the files from `origin/main` (`git show origin/main:<path>`), not the working tree, so that local edits don't change the answer. Say when the working tree differs.
2. **Regions:** each entry of `catalog/regions.yaml` (name, cloud, code, state), with its hub from `catalog/ipam.yaml` (`vnet-hub-<code>`, /20) or "no hub".
3. **Landing zones:** each `landing-zones/*.yaml`:
   - name, state, archetype, region, `spoke_cidr`, budget;
   - for `decommissioned`, the date its hold ends (`decommissioned_on + hold_days`);
   - for `cancelled`, "clean-up due after about 90 days".
4. **Stamps:** each `stamps/<lz>/<folder>/stamp.yaml`:
   - the stamp code (`shr`, or the customer code, then the product code and the environment);
   - template and version, environment, range;
   - its hostnames from `catalog/tenants.yaml`, with derived ones noted.
5. **Free ranges:**
   - `python .agents/skills/_shared/ipam.py hub azure`;
   - `… landing-zone prod`;
   - `… landing-zone sandbox`;
   - and `… stamp <lz>` for each active landing zone.
6. **Open PRs:** `gh pr list -R TrislabCompany/tl-cloud-infrastructure --state open --json number,title,author,reviewDecision,statusCheckRollup,body`. For each PR show:
   - its review decision;
   - the state of `plan`, `conftest`, `stamp-check` and `applied`;
   - any `Depends on #<n>`;
   - the next action: wait for checks, needs approval, ready for `/apply`, or a second `/apply` for a cancel.
7. **Live checks, optional, with `az`:**
   - each landing zone's subscription state: `az account subscription list --query "[].{name:displayName, state:state}" -o table`;
   - each stamp's Container Apps environment: `az graph query -q "Resources | where type =~ 'microsoft.app/managedenvironments' | project name, location, resourceGroup"`.
   - Point out anything in the catalog with nothing live, or the reverse.
8. **Report** as short tables, most relevant first. The user's question decides which sections to show.
