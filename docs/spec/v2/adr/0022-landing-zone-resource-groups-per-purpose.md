# ADR 0022: A landing zone has one resource group per purpose, and the shared ones are locked

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

A landing zone subscription holds two kinds of things. Some belong to the landing zone and are shared by all its stamps: the spoke network, the Key Vault, and for regulated landing zones the log workspace. The rest belong to single stamps, and each stamp already brings its own resource group, `rg-<stamp>`. Think of a shared office floor: the corridors and the safe belong to the building, and each tenant has their own rooms.

The shared things need a resource group too, and [03](../03-naming-conventions.md) has no names for it. There is also a risk: every stamp deploys with `spn-lz-<lz>-deploy`, which is Contributor on the whole subscription. One wrong stamp change could delete the landing zone's Key Vault or network, which every other stamp in it relies on.

Example: `cust-vbs-prod-sec` has `vnet-cust-vbs-prod-sec`, `kv-cust-vbs-prod-<nnnn>` and `log-cust-vbs-prod-sec`. Which resource groups hold them, and what stops a stamp from deleting them?

## The decision

The `landing-zone` module creates one resource group per purpose, in the landing zone's region:

| Resource group | Holds | Delete lock |
|---|---|---|
| `rg-<lz>-network` | The spoke `vnet-<lz>` and the Network Watcher `nw-<lz>` | No: stamps add and remove their subnets here |
| `rg-<lz>-security` | The Key Vault `kv-<scope>-<envtype>-<nnnn>` (and the CMK key for `prod-regulated`) | Yes |
| `rg-<lz>-monitoring` | The dedicated workspace `log-<lz>`, only when `dedicated_workspace` is `true` | Yes |

The locked groups get a `CanNotDelete` lock, created by the module. `spn-lz-<lz>-deploy` is Contributor and can't remove a lock, so no stamp can delete the Key Vault or the workspace.

## What this means in practice

- Stamps keep their own `rg-<stamp>` groups and never put anything into the landing zone's groups, except subnets into the spoke.
- A stamp that goes wrong can't delete the shared Key Vault or workspace. It could still delete the spoke, because the network group can't be locked (see technical details). Plan review is what catches that.
- Secrets are not affected. The lock only protects the Key Vault itself, not the secrets in it.
- The budget, the `access` grants and the pipeline identities are set on the subscription and need no resource group.
- The Network Watcher is created by the module. Otherwise Azure creates `NetworkWatcherRG` by itself when the spoke is created, without the mandatory tags, and the tag policy denies it.
- On decommissioning the groups and locks stay, together with the data, until the hold ends ([05 section 7](../05-landing-zones.md#7-lifecycle)).
- GCP has no resource groups. The project is the container, and labels mark the purpose.

## Options we did not choose

| Option | Why not |
|---|---|
| One `rg-<lz>` for everything | It can't be locked, because a lock on a group also blocks deleting subnets in its VNet, and stamps must be able to remove their subnets. So the Key Vault would have no protection from a stamp |
| The landing zone's resources in `rg-<lz>-network` and `rg-<lz>-core` (Key Vault and workspace together) | Works, but one group per purpose is easier to read in cost and access views, and the monitoring group exists only for regulated landing zones |
| Give `spn-lz-<lz>-deploy` Contributor only on the stamps' resource groups, not on the subscription | Stamps create their own resource groups and add subnets to the spoke, so the deploy identity needs rights on the subscription. A narrower identity is a bigger change and belongs in a later ADR if it is ever needed |
| Lock the network group too | A `CanNotDelete` lock on the group blocks deleting subnets, so no stamp could be decommissioned without a platform engineer removing the lock |

## Technical details

- **Module:** `azurerm_resource_group` for each group, with the mandatory tags; `azurerm_management_lock` with `lock_level = "CanNotDelete"` on `rg-<lz>-security` and `rg-<lz>-monitoring`; `azurerm_network_watcher` `nw-<lz>` in `rg-<lz>-network`.
- **Rights:** `spn-landingzones-apply` creates and deletes the locks with `Microsoft.Authorization/locks/*`. The condition on its User Access Administrator role only limits role assignments ([02 section 6](../02-architecture.md#6-identity-and-access)), so locks are allowed. Contributor has no rights on locks, which is what protects the groups from the deploy identity.
- **To check in the pilot:** a stamp removes its per-secret role assignments on the Key Vault when it is decommissioned. If the lock on `rg-<lz>-security` blocks deleting those role assignments, the lock moves from the group to the Key Vault alone, or is dropped for this group. Stamps are not affected otherwise.
- **Order in [05 section 4](../05-landing-zones.md#4-what-one-apply-creates):** the groups are created right after the subscription (step 2), before the spoke, the Key Vault and the workspace.
- **Names:** `nw` is the Cloud Adoption Framework abbreviation for Network Watcher. All names fit the 90-character limit for resource groups.
- **Spec:** the names are in [03 section 7.3](../03-naming-conventions.md#73-l2-application-landing-zones) and `nw` in [03 section 5](../03-naming-conventions.md#5-resource-type-abbreviations); [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 2 creates the groups and locks.
