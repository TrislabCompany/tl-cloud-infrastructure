# ADR 0023: The region service check is a script that reads each stamp template's requirements

> Part of [spec v2](../README.md).

- **Status:** rejected. Not needed for the initial build: no region beyond N6 is planned. Revisit with a new ADR when the first new region is added.
- **Date:** 2026-09-28

## The problem

Not every Azure region offers every service, and not every region offers every service across availability zones. Before we open a new region, we have to know that the things our stamps are built from exist there. It's like checking that a new branch office will have electricity, internet and a lift before signing the lease.

[ADR 0016](./0016-regions-added-when-needed.md) requires this check but lists nothing to check, and a checklist done by hand is easy to get wrong or skip. It also goes stale: when a stamp template starts using a new service, nobody updates the checklist. And some building blocks are outside Azure: `db-neon` and `cache-upstash` only run in the regions their vendors support.

Example: before allowing `swedencentral`, we need to know whether the `aca-app` template works there: Container Apps, PostgreSQL flexible server, Key Vault, and Neon and Upstash in or near the region. We also need to know whether Container Apps and PostgreSQL support zones there, for stamps with `zone_redundant: true` ([ADR 0017](./0017-availability-zones-per-stamp.md)).

## The decision

Each stamp template lists what it needs in a **`requirements.yaml`**, released with the template. The `landing-zone` module has one too, for what every landing zone needs. A script, **`scripts/check-region`**, checks a region against these files and is run by the pipeline in two places:

| When | What it checks | Result |
|---|---|---|
| The region PR (PR 1 in [05 section 5](../05-landing-zones.md#5-adding-a-region)), whenever `policy/regions.rego` changes | The `landing-zone` module and the latest release of every stamp template, in the new region | The PR **fails** if the landing zone's needs aren't met. Each template's result is posted as a PR comment: supported, supported without zones, or not supported |
| Every stamp plan | That stamp's template version, in its landing zone's region, with its `zone_redundant` setting | The plan **fails** if anything is missing, before apply |

So there is no manual checklist. The region PR shows which templates can run in the region, and a stamp that can't run there fails at plan.

## What this means in practice

- "Step 0" in [05 section 5](../05-landing-zones.md#5-adding-a-region) becomes part of the region PR, not a separate manual step. This fits N11: only the seed is manual.
- A region can be allowed even if some templates can't run there. The PR comment says which ones, and reviewers decide whether that is acceptable for the product that needs the region.
- When a template starts using a new service, its `requirements.yaml` changes in the same `tl-platform` release. The next stamp plan checks it, so the check never goes stale.
- A stamp with `zone_redundant: true` in a region where one of its services has no zones fails at plan, with the service named.
- Quotas are not checked: the new landing zone's subscription doesn't exist yet when the region is added. A missing quota still shows up at apply.

## Options we did not choose

| Option | Why not |
|---|---|
| A checklist per stamp template in 06, done by hand | Easy to skip or get wrong, goes stale when a template changes, and is a manual step against N11 |
| Check only on the region PR | A stamp template released after the region was added, or a stamp turning on `zone_redundant` later, would never be checked |
| Check only on stamp plans | The region would be allowed and its hub built before we learn that the product that needed it can't run there |
| Try a deployment in the region (a canary stamp) | Slow, costs money, and leaves resources to clean up. The provider metadata answers the same question |

## Technical details

- **`requirements.yaml`**, one per stamp template and one for the `landing-zone` module:

  ```yaml
  azure:
    resource_types:              # must be offered in the region
      - Microsoft.App/managedEnvironments
      - Microsoft.DBforPostgreSQL/flexibleServers
      - Microsoft.KeyVault/vaults
    zone_redundant:              # must support zones when zone_redundant is true
      - Microsoft.App/managedEnvironments
      - Microsoft.DBforPostgreSQL/flexibleServers
  saas:                          # vendor regions allowed for this Azure region
    neon:    { swedencentral: [azure-gwc] }
    upstash: { swedencentral: [eu-central-1] }
  ```

  The vendor region codes above are examples. The SaaS entries map an Azure region to the vendor regions that are close enough and in the EU (N6). They are kept by hand in the template, because vendors don't publish this as metadata. A missing entry counts as "not supported".
- **How the script checks Azure:** the resource provider API (`GET /subscriptions/{id}/providers/{namespace}`) lists, for each resource type, the regions it is offered in and its zone mappings. The script needs only Reader on a subscription: `spn-platform-plan` on the region PR, `spn-lz-<lz>-plan` on a stamp plan.
- **What the landing zone needs** (`landing-zone` module's `requirements.yaml`): virtual networks, Network Watcher, Key Vault and Log Analytics. A landing zone itself doesn't need zones.
- **GCP:** the same script with a GCP backend, using the Cloud Run, Cloud SQL and Memorystore location lists. Resource types are service names in a `gcp:` block of the same file.
- **Where it lives:** the script and its tests are in `tl-cloud-infrastructure/scripts/`. `requirements.yaml` is in each template's folder in `tl-platform`, and in `modules/landing-zone/`.
- **Relation to [ADR 0016](./0016-regions-added-when-needed.md):** ADR 0016 requires the check; this ADR says how it is done. ADR 0016 stays as it is.
- **Spec changes on acceptance:**
  - In [05 section 5](../05-landing-zones.md#5-adding-a-region), fold row 0 into PR 1 as "the region check runs on this PR (ADR 0023)".
  - Add the stamp plan check to the list of checks in `06-stamp-templates.md` when it is written, with `requirements.yaml` in the template spec.
  - Drop question 6 from [05 section 8](../05-landing-zones.md#8-open-questions).
