---
name: landing-zone-decommission
description: Decommission a landing zone with a hold, once its stamps are destroyed; the subscription and data stay until landing-zone-cancel. Also takes a decommissioned landing zone back to active during its hold. One PR. Use when the user asks to decommission, retire, remove, delete, deprovision, tear down or shut down a landing zone and its data may still be needed.
disable-model-invocation: true
metadata:
  owner: infrastructure
---

# landing-zone-decommission

Step 2 of removing a landing zone with a hold. The order of the whole removal:

1. Destroy the stamps ([`stamp-destroy`](../stamp-destroy/SKILL.md)).
2. **Decommission** (this skill).
3. Hold, `hold_days`, 1 day by default.
4. Cancel ([`landing-zone-cancel`](../landing-zone-cancel/SKILL.md)).
5. Clean up, about 90 days later (`landing-zone-cancel clean-up`).

When nobody needs the data, skip this skill and use `landing-zone-cancel now`, which goes from `active` to `cancelled` in one PR.

**What the apply removes:**
- both halves of the hub peering and the private DNS links;
- the plan and deploy identities with their role assignments;
- the Environment `lz-<lz>` with its variables;
- the "Edge stamp reader" assignments and the `access` grants.

It then moves the subscription to `mg-decommissioned`, where all writes are denied. The subscription, its resource groups, the spoke, the Key Vault, the workspace, the data and the costs stay.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Commands

| Command | Does |
| --- | --- |
| `landing-zone-decommission <lz> [hold_days]` | `active` → `decommissioned` |
| `landing-zone-decommission <lz> undo` | `decommissioned` → `active`, allowed only during the hold |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)).
2. **Preconditions.** Stop with the reason when one fails.
   - `landing-zones/<lz>.yaml` exists on `origin/main`, with `state: active` (for `undo`: `decommissioned`, and today is before `decommissioned_on + hold_days`).
   - `stamps/<lz>/` holds no stamp folder, and `catalog/ipam.yaml` lists no `stamps` under the landing zone. If any remain, list them and point to `stamp-destroy`.
   - No open PR adds a stamp to the landing zone.
   - The landing zone is not an experiment: an experiment ends by its `ttl`, or with `landing-zone-cancel now`.
3. **Ask about the data:**
   - Is there data anyone needs?
   - During the hold, platform admins can still read and export it through PIM.
   - Propose `hold_days` (default 1). Record the answer in the PR body.
4. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)).
5. **Write**, on branch `decommission-<lz>` (`undo-decommission-<lz>`).
   - **`landing-zones/<lz>.yaml`:**
     - change `state: active` to `state: decommissioned`;
     - add `decommissioned_on: <today, YYYY-MM-DD>`;
     - add `hold_days: <n>` only when it is not 1.
     - For `undo`, set `state: active` and leave `decommissioned_on` in place.
   - **`platform/azure/identity/groups.tf`,** prod landing zones only: delete the `data-<lz>-readers` and `data-<lz>-admins` entries. The `platform` apply of the same PR deletes the groups. For `undo`, add them back.
6. **Check and open the PR** ([shared steps 4 and 5](../_shared/pr.md#4-check)).
   - **Title:** "Decommission the landing zone <lz>" (or "Take the landing zone <lz> back to active").
   - **Body:**
     - the hold;
     - the data answer;
     - the manual step;
     - "the plan must show the deletes listed above and the move to `mg-decommissioned`, and no delete of a resource group".
   - **The manual step:** before `/apply`, the tenant owner removes the lock `lock-rg-platform-state`, and puts it back once the apply is done. The lock blocks deleting the identities' role assignments on the state containers, and removing it needs "Access management for Azure resources". Put it in the body and in the final message.
7. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)). Say when the hold ends, and that `landing-zone-cancel <lz>` opens the cancel PR after it.
