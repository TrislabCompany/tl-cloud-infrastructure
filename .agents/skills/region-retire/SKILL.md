---
name: region-retire
description: Retire a cloud region once nothing uses it — delete its hub (platform/azure/connectivity/hub-<code>.tf and its range in catalog/ipam.yaml), then set state retired in catalog/regions.yaml, never deleting the entry — as two dependent PRs in tl-cloud-infrastructure, opened with the user's own gh credentials. Use when the user asks to retire, remove, delete, deprovision, decommission or tear down a region or a hub.
disable-model-invocation: true
metadata:
  owner: infrastructure
---

# region-retire

Ends a region's life, in the reverse order of [`region-register`](../region-register/SKILL.md). A region is retired only after its last landing zone and its hub are gone. Its entry in `catalog/regions.yaml` stays with `state: retired`, so its code is never reused. The hub's range is freed when its entry leaves `catalog/ipam.yaml`.

| PR | Change | Root, Environment | What happens in the cloud |
| --- | --- | --- | --- |
| 1 | Delete `hub-<code>.tf` and the hub's entry in `catalog/ipam.yaml` | `platform/azure/connectivity`, `platform` | The hub's role assignments, `GatewaySubnet`, Network Watcher, VNet and `rg-hub-<code>` are destroyed |
| 2 | `state: retired` in `catalog/regions.yaml` | `platform/azure/governance`, `platform` | The region leaves the `mg-root` allowed-locations assignment: nothing new can be created there |

**Not covered by the spec:** the spec states only the precondition. These PRs follow the repository's rules for removing a root and freeing a range. Say so in each PR body, so the reviewers check the destroy plan with care.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required |
| --- | --- |
| `region` or `code` | yes |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)), with `az` signed in.
2. **Preconditions.** Stop with the list when any fails.
   - The region is `active` in `catalog/regions.yaml`.
   - No file in `landing-zones/` has `region: <region>`, whatever its state. A cancelled landing zone's file is deleted by its clean-up PR (see [`landing-zone-cancel`](../landing-zone-cancel/SKILL.md)), about 90 days after the cancel.
   - No landing zone in `catalog/ipam.yaml` has a name ending in `-<code>` or `-<code>-<nn>`.
   - **Azure:** no VNet other than the hub's lives in the region:

     ```powershell
     az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' and location =~ '<region>' | project name, resourceGroup, subscriptionId" -o table
     ```

     The query should list only `vnet-hub-<code>`. Spokes would still peer with the hub.
   - **Hub peerings:** `az network vnet peering list -g rg-hub-<code> --vnet-name vnet-hub-<code> -o table` is empty.
   - No VPN gateway (`vgw-hub-<code>`) exists. If one does, stop: removing it needs its own plan with the platform team.
3. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)): the hub and resource group that will be destroyed, the range that will be freed, and the two PRs.

### PR 1: delete the hub

Branch `retire-hub-<code>`.

- **`platform/azure/connectivity/hub-<code>.tf`:** delete the file (`git rm`).
  - If it is `hub-neu.tf`, it also holds the shared data sources and `local.tags` that other files use. Move those into a new `hub-shared.tf` in the same PR, and say so in the body.
- **`catalog/ipam.yaml`:** delete the `vnet-hub-<code>` entry under `hubs`.
- **Check:** `tofu -chdir=platform/azure/connectivity init -backend=false`, then `validate`.
- **Title:** "Delete the hub of <region> (vnet-hub-<code>)".
- **Body:** "The plan must show only destroys of `rg-hub-<code>` and the resources in it, and of the two role assignments on the VNet."

### PR 2: retire the region

Branch `retire-region-<code>`, opened as a draft with `Depends on #<PR 1>`.

- **`catalog/regions.yaml`:** change `state: active` to `state: retired` on the region's entry. Never delete the entry: the catalog rules refuse that.
- **Title:** "Retire the region <region> (<code>)".
- **Body:** "Mark ready after PR 1 is applied."

4. **Check, commit, push, open** each PR, then **stop** ([shared steps 4 to 6](../_shared/pr.md#4-check)).
