# Architecture Decision Records

> Part of [spec v2](../README.md).

An **Architecture Decision Record (ADR)** is a short note that captures one important decision: the problem we faced, what we chose, and what we gave up. Each ADR opens with a plain-language explanation that someone without a technical background can follow. It lets anyone understand later *why* the platform looks the way it does.

## Index

| # | Title | Status | Date |
|---|---|---|---|
| [0001](./0001-no-company-token-in-names.md) | Names don't carry the company token | accepted | 2026-09-25 |
| [0002](./0002-globally-unique-names-get-a-suffix.md) | Names that must be globally unique get a 4-digit suffix | accepted | 2026-09-25 |
| [0003](./0003-short-codes-for-customers-and-products.md) | Customers and products get a short code | accepted | 2026-09-25 |
| [0004](./0004-environment-types-prod-and-sandbox.md) | Environments are either production or sandbox | accepted | 2026-09-25 |
| [0005](./0005-management-groups-by-archetype.md) | Management groups follow the type of environment, not the customer | accepted | 2026-09-25 |
| [0006](./0006-monorepo-with-path-based-identity.md) | One infrastructure repository; the folder decides which identity applies it | accepted | 2026-09-25 |
| [0007](./0007-customer-dev-and-test-share-sandbox-lz.md) | A customer's dev and test share one sandbox landing zone | accepted | 2026-09-25 |
| [0008](./0008-gcp-built-on-first-customer.md) | GCP follows the same model, built only when the first GCP customer arrives | accepted | 2026-09-25 |
| [0009](./0009-ring-based-template-rollout.md) | Template upgrades roll out ring by ring | accepted | 2026-09-25 |
| [0010](./0010-top-management-group-mg-root.md) | The top management group is `mg-root` | accepted | 2026-09-25 |
| [0011](./0011-one-invoice-with-a-section-per-owner.md) | One Azure invoice, with a section per customer | accepted | 2026-09-25 |
| [0012](./0012-tenant-catalog-stays-yaml.md) | The tenant catalog stays a YAML file in the repository | accepted | 2026-09-28 |
| [0013](./0013-nsg-rules-without-network-manager.md) | Sandbox and production are separated by NSG rules, without Network Manager | superseded by 0025 | 2026-09-28 |
| [0014](./0014-gcp-region-europe-west8.md) | The first GCP region is `europe-west8` (Milan) | accepted | 2026-09-28 |
| [0015](./0015-one-landing-zone-one-region.md) | A landing zone is in exactly one region | accepted | 2026-09-28 |
| [0016](./0016-regions-added-when-needed.md) | A region is added only when a product needs it | accepted | 2026-09-28 |
| [0017](./0017-availability-zones-per-stamp.md) | Availability zones are a setting per stamp | accepted | 2026-09-28 |
| [0018](./0018-hub-peering-custom-role.md) | The landing zone pipeline may only add and remove peerings on the hub | accepted | 2026-09-28 |
| [0019](./0019-github-app-for-landing-zone-environments.md) | A GitHub App creates each landing zone's GitHub Environment | accepted | 2026-09-28 |
| [0020](./0020-landing-zone-links-private-dns-zones.md) | The landing zone pipeline links the private DNS zones to its own spoke | accepted | 2026-09-28 |
| [0021](./0021-region-order-checked-against-live-state.md) | Each region PR checks at plan time that the step before it is live | accepted | 2026-09-28 |
| [0022](./0022-landing-zone-resource-groups-per-purpose.md) | A landing zone has one resource group per purpose, and the shared ones are locked | accepted | 2026-09-28 |
| [0023](./0023-region-service-check-from-template-requirements.md) | The region service check is a script that reads each stamp template's requirements | rejected | 2026-09-28 |
| [0024](./0024-deploy-identity-grants-stamp-roles.md) | A landing zone's deploy identity may grant the stamps' own roles and write their secrets | accepted | 2026-09-28 |
| [0025](./0025-stamp-nsg-carries-isolation-rules.md) | Every stamp's NSG carries the sandbox/production deny rules | accepted | 2026-09-28 |
| [0026](./0026-vendor-credentials-through-lz-environment.md) | Vendor credentials reach a stamp through its landing zone's GitHub Environment | accepted | 2026-09-28 |
| [0027](./0027-global-edge-writes-stamp-dns-records.md) | `global/edge` writes every stamp's DNS records, and the stamp only binds its hostnames | accepted | 2026-09-28 |
| [0028](./0028-platform-built-in-empty-tenant.md) | The platform is built in an empty tenant; nothing is adopted | accepted | 2026-09-28 |
| [0029](./0029-environment-approval-gate-until-itop.md) | The GitHub Environment approval is the only apply gate until iTop runs | accepted | 2026-09-28 |
| [0030](./0030-pipeline-is-plain-github-actions.md) | The pipeline is plain GitHub Actions workflows | proposed | 2026-09-28 |
| [0031](./0031-environment-reviewers-and-layer-environments.md) | Reviewers follow the landing zone's archetype, and the seed creates the layer Environments | proposed | 2026-09-28 |
| [0032](./0032-state-access-by-layer-and-path.md) | State access is split per layer and per landing zone, and plans don't lock | proposed | 2026-09-28 |
| [0033](./0033-gcp-state-storage-built-first.md) | GCP state storage is built before the first GCP customer | proposed | 2026-09-28 |
| [0034](./0034-platform-apply-identity-rights.md) | What the platform apply identity may do, and which rights stay manual | proposed | 2026-09-28 |

## Adding an ADR

1. Copy [`0000-template.md`](./0000-template.md) to `NNNN-short-title.md`, using the next free number.
2. Set the status to `proposed` and fill in every section. Start with the plain-language explanation.
3. Add a row to the index above.
4. When the decision is approved, set the status to `accepted`.
5. An accepted ADR is never rewritten. To change a decision, write a new ADR and set the old one to `superseded by NNNN`.

Statuses: `proposed` · `accepted` · `superseded by NNNN` · `rejected`.
