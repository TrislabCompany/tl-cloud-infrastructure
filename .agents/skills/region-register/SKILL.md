---
name: region-register
description: Register a new cloud region and build its hub, or build the hub of a region that is already registered without one — allow the region in catalog/regions.yaml with its code, reserve the hub's /20 in catalog/ipam.yaml, then write platform/azure/connectivity/hub-<code>.tf — as two dependent PRs in tl-cloud-infrastructure, opened with the user's own gh credentials. Use when the user asks to add, register, enable, provision or create a region, a hub or a new location, or wants a landing zone in a region that has no hub yet.
metadata:
  owner: infrastructure
---

# region-register

Adds a region in the order the pipeline checks against live state. A PR applied out of order fails at plan and creates nothing.

| PR | Change | Root, Environment | What happens in the cloud |
| --- | --- | --- | --- |
| 1 | The region in `catalog/regions.yaml` and its hub's /20 in `catalog/ipam.yaml` | `platform/azure/governance`, `platform` | The `mg-root` allowed-locations policy assignment is updated to include the region. Nothing is created |
| 2 | `platform/azure/connectivity/hub-<code>.tf` | `platform/azure/connectivity`, `platform` | `rg-hub-<code>`, `vnet-hub-<code>` with an empty `GatewaySubnet`, `nw-hub-<code>`, and on the VNet the role "Landing zone hub peering" for `spn-landingzones-apply` and Reader for `spn-landingzones-plan` |

A landing zone in the region follows with [`landing-zone-create`](../landing-zone-create/SKILL.md). The hub has no firewall, Bastion or NAT gateway. A VPN gateway is added only when a stamp needs private cross-cloud traffic; that is not part of this skill.

Follow [the shared steps](../_shared/pr.md) for the preflight, the checks and the PR. The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required | Rule |
| --- | --- | --- |
| `cloud` | yes | `azure`. A GCP region can be registered (PR 1 only), but its hub needs `platform/gcp/connectivity`, which doesn't exist yet: say so and stop after PR 1 |
| `region` | yes | The cloud's region name, for example `swedencentral`. It must be in an EU member state, on the list in `policy/regions.rego` (`eu_regions`) |
| `code` | no | 2–4 lowercase letters and digits. Propose one from the name (`swedencentral` → `sec`, `germanywestcentral` → `gwc`), and let the user change it |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)). This skill also reads Azure: `az account list-locations --query "[?name=='<region>'].{name:name, display:displayName, geo:metadata.geographyGroup}" -o table` must list the region.
2. **Read the state** of `catalog/regions.yaml`, `catalog/ipam.yaml` (`hubs`) and `platform/azure/connectivity/hub-*.tf`.
   - **The region is not registered:** open PR 1 and PR 2.
   - **It is registered and `active` but has no hub** (for example `italynorth` today): open only PR 2. Use its code from `regions.yaml`; the hub's /20 goes into PR 2 together with `hub-<code>.tf`.
   - **It is `retired`:** a region is registered once. Setting it back to `active` is a governance decision; stop and say so.
   - **It already has a hub:** nothing to do. Point to `landing-zone-create`.
3. **Check the code:**
   - it matches `^[a-z0-9]{2,4}$`;
   - it is in neither `regions.yaml` (any cloud) nor an owner code in `products.yaml`;
   - it is not a reserved token (AGENTS.md, "Names").
4. **Compute the hub range:** `python .agents/skills/_shared/ipam.py hub <cloud>` gives the next free /20 in the cloud's half of the hub pool, for example `10.0.16.0/20`. The `GatewaySubnet` is the /27 at its start, for example `10.0.16.0/27`.
5. **Service check, region beyond the first six only:** ask the user to confirm that every service the stamp templates use (Container Apps, Key Vault, Log Analytics, the managed identities) is offered in the region. Record the answer in the PR body.
6. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)): the region, code, hub name `vnet-hub-<code>`, its /20 and `GatewaySubnet`, both PRs and their order.

### PR 1: register the region

Branch `region-<code>`. Skip this PR when the region is already registered.

- **`catalog/regions.yaml`:** append

  ```yaml
    - name: <region>
      cloud: <cloud>
      code: <code>
      state: active
  ```

- **`catalog/ipam.yaml`:** under `hubs`, after the last hub, append

  ```yaml
    - name: vnet-hub-<code>
      cloud: azure
      region: <region>
      cidr: <hub /20>
      subnets:
        GatewaySubnet: <first /27>
  ```

  (`snet-hub-<code>` for GCP.)
- **Title:** "Register the region <region> (<code>) and reserve its hub range".
- **Body:** the governance update; "allow for policy propagation before PR 2 is applied".

### PR 2: build the hub

Branch `hub-<code>`, from `origin/main` when PR 1 is already merged. Otherwise from PR 1's branch, so that PR 2 sees its catalog entries. When the region was already registered, the `ipam.yaml` hub entry above goes into this PR.

- **`platform/azure/connectivity/hub-<code>.tf`:** a copy of `hub-neu.tf` in which every `neu` becomes `<code>` and `northeurope` becomes `<region>`. That covers the locals `hubs_<code>`/`hub_<code>`, the resource names, `"vnet-hub-<code>"` in the filter, the location, and the comment's first line ("The hub of <region>").
  - Don't copy `data "azurerm_subscription" "current"`, the two `data "azuread_service_principal"` blocks or the `tags` local: they exist once, in `hub-neu.tf`, and the new file reuses them (`local.tags`, `data.azuread_service_principal.landingzones_apply`, `…landingzones_plan`). A second definition fails `tofu validate`.
  - The new file's `locals` block holds only `hubs_<code>` and `hub_<code>`.
- **Private DNS:** `private-dns.tf` has no `privatelink.*` zone yet, so there is nothing to link. If zones exist by then, add a link from each zone to `vnet-hub-<code>` in the same way the file links the others.
- **Checks:** `tofu -chdir=platform/azure/connectivity init -backend=false`, then `validate`. Remove the `.terraform` folder afterwards.
- **Title:** "Build the hub of <region> (vnet-hub-<code>)".
- **Body:** ends with `Depends on #<PR 1>` when PR 1 exists. Open it with `gh pr create --draft` while PR 1 is not applied, and say: "Mark ready after PR 1 is applied and the policy has propagated (about 30 minutes)".

7. **Check, commit, push, open** each PR ([shared steps 4 and 5](../_shared/pr.md#4-check)), then **stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)).
