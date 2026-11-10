---
name: landing-zone-cancel
description: Cancel a landing zone's subscription in tl-cloud-infrastructure — after its hold (state decommissioned → cancelled), or at once without a hold (active → cancelled with hold_days 0), or end an experiment — and later open the clean-up PR that deletes landing-zones/<lz>.yaml and frees its /20 once Azure has deleted the subscription; each as one PR opened with the user's own gh credentials. Use when the user asks to cancel, delete, destroy, remove, deprovision or tear down a landing zone or its subscription, stop its costs, or clean up a cancelled landing zone.
metadata:
  owner: infrastructure
---

# landing-zone-cancel

Ends a landing zone, which can't be undone. The first `/apply` deletes the resource groups with everything in them. The second `/apply` of the same PR cancels the subscription, and the PR then merges. Azure keeps the cancelled subscription disabled for about 90 days, then deletes it, and the clean-up PR follows. An experiment has no resource groups, so one `/apply` cancels it.

Only `state: cancelled` cancels a subscription: the `landingzones` layer sets `prevent_cancellation_on_destroy`.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Commands

| Command | From | PR |
| --- | --- | --- |
| `landing-zone-cancel <lz>` | `decommissioned` on `main`, with the hold over | `state: cancelled` |
| `landing-zone-cancel <lz> now` | `active` on `main`, not an experiment, nobody needs the data | `state: cancelled`, `decommissioned_on: <today>`, `hold_days: 0` |
| `landing-zone-cancel <lz> clean-up` | `cancelled` on `main`, and the subscription no longer listed in Azure | Deletes the file and its range |

An experiment is ended with `landing-zone-decommission` and `hold_days: 0` (or by its `ttl`), then `landing-zone-cancel <lz>`.

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)), with `az` signed in.
2. **Preconditions** (from `origin/main`'s files). The catalog rules enforce the same in the PR's plan.
   - **`cancel`:**
     - `state: decommissioned`;
     - today ≥ `decommissioned_on` + `hold_days` (1 by default, 0 for an experiment).
     - Otherwise say when the hold ends, and stop.
   - **`now`:**
     - `state: active`;
     - not `exp-*`;
     - no stamp folders under `stamps/<lz>/` and no `stamps` under the landing zone in `catalog/ipam.yaml`. Otherwise point to [`stamp-destroy`](../stamp-destroy/SKILL.md);
     - ask the user to confirm, in words, that nobody needs the data;
     - for prod, delete the `data-<lz>-*` groups as in [`landing-zone-decommission`](../landing-zone-decommission/SKILL.md).
   - **`clean-up`:**
     - `state: cancelled`;
     - `az account subscription list --query "[?displayName=='sub-<lz>']" -o tsv` is empty. While Azure still lists it as `Disabled`, say it is about 90 days after the cancel, and stop.
3. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)). For `cancel` and `now`, say plainly:
   - every resource and all data in the subscription are deleted;
   - the subscription is cancelled;
   - this can't be undone.
4. **Write**, on branch `cancel-<lz>` (`clean-up-<lz>`).
   - **`cancel`:** in `landing-zones/<lz>.yaml`, `state: decommissioned` → `state: cancelled`.
   - **`now`:** `state: cancelled`, plus `decommissioned_on: <today>` and `hold_days: 0`.
   - **`clean-up`:**
     - `git rm landing-zones/<lz>.yaml`;
     - delete the landing zone's entry under `landing_zones` in `catalog/ipam.yaml`, which frees the range;
     - if the owner is being offboarded (ask), set its `state: retired` of the tenant in `catalog/products.yaml`. Never delete it.
5. **Check and open the PR** ([shared steps 4 and 5](../_shared/pr.md#4-check)).
   - **Titles:**
     - "Cancel the landing zone <lz>";
     - "Cancel the landing zone <lz> without a hold";
     - "Clean up the cancelled landing zone <lz>".
   - **Body** for `cancel` and `now`:
     - "First `/apply`: deletes the resource groups. `applied` stays red and the PR stays open. Second `/apply`, approved again: cancels the subscription and merges the PR."
     - **`now` only:** the tenant owner removes the lock `lock-rg-platform-state` before the first `/apply` (it deletes the identities), and puts it back after.
   - **Body** for `clean-up`: "planned with `-destroy` from `main`'s copy; removes the key from state and cancels nothing".
6. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)). After a cancel, say that `landing-zone-cancel <lz> clean-up` follows in about 90 days.
