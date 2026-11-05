---
name: landing-zone-create
description: Create an application landing zone in tl-cloud-infrastructure — choose its scope (products, cust-<code>, prdt-<code>), environment type (prod or sandbox) or experiment, region with a hub, archetype, budget and access; reserve its /20 in catalog/ipam.yaml; write landing-zones/<lz>.yaml; add the prod data access groups — as one PR opened with the user's own gh credentials. Use when the user asks to create, add, provision, set up or build a landing zone, a subscription for products or a customer, a prod or sandbox environment class, or an experiment subscription.
metadata:
  owner: infrastructure
---

# landing-zone-create

One PR, applied before its stamps. Its apply creates:
- the subscription `sub-<lz>` in its management group;
- the spoke `vnet-<lz>` peered with the region's hub;
- the Key Vault, the workspace and the budget;
- the plan and deploy identities;
- the GitHub Environment `lz-<lz>` (reviewers `devops`), which every stamp of the landing zone needs.

Stamps come in a later PR with [`stamp-create`](../stamp-create/SKILL.md).

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required | Values and rule |
| --- | --- | --- |
| `scope` | yes | `products` (Trislab's shared products), `cust-<code>` (a customer), `prdt-<code>` (a graduated product), or `experiment` |
| `envtype` | yes, except experiment | `prod` or `sandbox` |
| `region` | yes, except experiment | An `active` region in `catalog/regions.yaml` **with a hub** in `catalog/ipam.yaml`. Without a hub, run [`region-register`](../region-register/SKILL.md) first |
| `archetype` | yes | `standard`. Two others exist: `experiment`, given by the scope, and `regulated`, which is refused until its CMK key is built: say so and stop |
| `budget` | yes | Monthly euros, a whole number above 0, at most 200 for an experiment. Propose 10 for a sandbox and ask for prod |
| `access` | no | Groups and roles (Reader, Contributor, Key Vault Reader, Key Vault Secrets Officer). Default: `grp-devops`, Contributor, `pim: true`, as in `products-sandbox-neu.yaml`. In prod, the module itself turns `grp-devops`'s Contributor and Key Vault Secrets Officer into Reader, and gives those roles to `grp-platform-admins`. Write the file the same way in both |
| `production_data` | no, prod only | Leave it out unless the user says the landing zone will hold data someone depends on. Once `true`, it never goes back |
| `topic`, `ttl` | experiment only | `exp-<topic>`; `ttl` such as `30d`, at most `90d` |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)).
2. **Read the state:** `catalog/owners.yaml`, `regions.yaml`, `ipam.yaml`, `landing-zones/*.yaml`, `platform/azure/identity/groups.tf`.
3. **Check the owner:**
   - `cust-<code>`: an `active` customer with that `code` in `owners.yaml`.
   - `prdt-<code>`: an `active` product with that `code`.
   - `products` and experiments need none.
   - A missing owner is onboarding, not this skill. Stop, and say the owner entry comes first.
   - For a customer, also check that `grp-cust-<code>-admins` exists: `az ad group show -g grp-cust-<code>-admins --query id -o tsv`. If it doesn't, say that the customer's sandbox Access needs it.
4. **Build the name:**
   - `<scope>-<envtype>-<region code>`. If that name is in `landing-zones/` or `ipam.yaml`, or was ever used, add `-02`, `-03`, … (never reused). Check `git log --all --oneline -- landing-zones/<name>.yaml` for earlier use.
   - Experiments: `exp-<topic>`.
   - The name must match `^(?:products|cust-[a-z]{2,3}|prdt-[a-z]{2,3})-(prod|sandbox)-[a-z0-9]{2,4}(?:-[0-9]{2})?$` (or `exp-…`).
5. **Compute the range:** `python .agents/skills/_shared/ipam.py landing-zone <envtype>`, which gives the next free /20 of the pool. Experiments have no range.
6. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)): name, subscription, management group (`mg-lz-standard` or `mg-experiments`), region and hub, range, budget, access, data access groups.
7. **Write**, on branch `lz-<name>`.

   - **`landing-zones/<name>.yaml`**, in the style of `products-sandbox-neu.yaml`:

     ```yaml
     # <one line: whose landing zone and what it is for> (05 section 2).
     name: <name>
     state: active
     cloud: azure
     archetype: standard
     owner: { products: true }          # or { customer: <code> } / { product: <code> } / { platform: true }
     subscription: sub-<name>
     region: <region>
     network:
       spoke_cidr: <the /20>
     budget:
       monthly_eur: <n>
     access:
       - group: grp-devops
         role: Contributor
         pim: true
     ```

     An experiment has `archetype: experiment`, `owner: { platform: true }`, `ttl: <n>d`, and no `region` or `network`.
   - **`catalog/ipam.yaml`**, not for experiments: append under `landing_zones`

     ```yaml
       - name: <name>
         cidr: <the /20>
     ```

   - **`platform/azure/identity/groups.tf`**, **prod only:** the `landing-zone` module reads `grp-data-<name>-readers` and `grp-data-<name>-admins`, and its plan fails without them. Add to `local.groups`, after the sandbox data groups:

     ```hcl
         data-<name>-readers = {
           name        = "grp-data-<name>-readers"
           description = "Read the data of the stamps in <name> (ADR 0052)."
         }
         data-<name>-admins = {
           name        = "grp-data-<name>-admins"
           description = "Administer the data of the stamps in <name> (ADR 0052)."
         }
     ```

     Skip this when the entries already exist. A sandbox landing zone uses the shared `grp-data-sandbox-*`, and a regulated one uses `grp-regulated-admins`.

     **The groups go in a PR of their own, opened first,** on branch `identity-data-groups-<name>`, titled "Add the data access groups of <name>", root `platform/azure/identity`. The landing zone's plan reads the groups from Entra, so in a single PR it fails until the groups are applied, and a failed plan leaves no saved plan to apply. The landing zone PR then ends its body with `Depends on #<groups PR>` and is re-planned when that one is applied.

     Write the two PRs on two branches, each from `origin/main`. The landing zone PR never touches `groups.tf`: not even a commit that adds the groups and a later one that removes them. Once the groups PR is merged, such a commit removes the groups from `main`'s file, and the landing zone's `/apply` deletes them (this happened on PR #93). To re-plan the landing zone PR after the groups are applied, rebase it on `origin/main`. Then `git diff --stat origin/main...HEAD` must list only `landing-zones/<name>.yaml` and `catalog/ipam.yaml`. `policy/catalog.rego` also denies a plan that deletes a data access group of a landing zone that isn't cancelled.
8. **Check** ([shared step 4](../_shared/pr.md#4-check)): `tofu fmt -check -recursive`, `check-catalog.py`, and for prod `tofu -chdir=platform/azure/identity init -backend=false` then `validate`.
9. **Open the PR** ([shared step 5](../_shared/pr.md#5-commit-push-open-the-pr)).
   - **Title:** "Create the landing zone <name>".
   - **Roots:** `landing-zones/_root` key `<name>`; for prod, the groups PR's root `platform/azure/identity` is applied before it.
   - **Expected re-runs in the body:**
     - A new root: the first `/apply` only creates the state of `landing-zones/_root` key `<name>`. The next `/apply` plans the root again and applies it after a second approval.
     - `MissingSubscriptionRegistration` on the first apply: run `/apply` again.
     - The budget fails with `401 Unauthorized` for up to 48 hours on a new subscription: every other step is applied and the PR stays open. Wait, then run `/apply` again.
   - **After the apply:** "the Environment `lz-<name>` exists; stamps can be created with `stamp-create`".
10. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)).
