# 03 — Naming conventions

> Part of [spec v2](./README.md). Defines every name used in [`02-architecture.md`](./02-architecture.md): management groups, subscriptions, projects, landing zones, stamps, resources, identities and tags. The reasons behind the main rules are recorded in [ADRs 0001–0004](./adr/README.md).

## 1. Principles

1. **No company token.** Every resource belongs to Trislab, so no name carries `tl` or `trislab` ([ADR 0001](./adr/0001-no-company-token-in-names.md)).
2. **Lowercase, hyphen-separated.** The only exception is storage accounts, whose API forbids hyphens: tokens are concatenated.
3. **General to specific**, left to right: type, then scope, then purpose, then environment, then region.
4. **Shortest recognisable token.** Long words get a fixed abbreviation (section 3) and owners get a short code (section 4, [ADR 0003](./adr/0003-short-codes-for-customers-and-products.md)).
5. **Region token only when the resource is pinned to a region for good.** A hub VNet carries `neu`. A landing zone is in one region for good, so its name ends in the region token, e.g. `cust-oc-prod-neu` ([ADR 0015](./adr/0015-one-landing-zone-one-region.md)). A stamp does not carry one: it runs in its landing zone's region.
6. **Globally unique types get a 4-digit suffix** (section 6, [ADR 0002](./adr/0002-globally-unique-names-get-a-suffix.md)).
7. **A correct grammar is not enough.** Every name is checked against the cloud's length and character limits (section 10) before first use.
8. **No cloud token.** No name ends in `-azure` or `-gcp`. Each cloud has its own resource types (section 5) and its own state backend, so the cloud is always known from context. A cloud name appears only where it names the *other* end of a connection, e.g. `conn-hub-neu-to-gcp`.
9. **Resource name and display name are the same.** Where a resource has both an ID and a display name (management group, subscription alias and display name, invoice section, app registration), both are set to the same value. The only exception is `mg-root`, whose display name is "Trislab" ([ADR 0010](./adr/0010-top-management-group-mg-root.md)).

## 2. Grammar

```text
<type>-<scope>[-<purpose>][-<envtype>][-<region>][-<nnnn>]
```

| Part | Meaning | Present when |
|---|---|---|
| `<type>` | Resource-type abbreviation (section 5) | Always |
| `<scope>` | Who or what the resource belongs to: a reserved scope, a landing zone name or a stamp code (sections 3 and 7) | Always |
| `<purpose>` | Sub-purpose, to tell apart several resources of the same type in one scope (e.g. `state`, `web`) | Only when needed |
| `<envtype>` | `prod` or `sandbox` ([ADR 0004](./adr/0004-environment-types-prod-and-sandbox.md)) | When the scope doesn't already contain it |
| `<region>` | Region code (section 3) | Only for region-pinned resources (principle 5) |
| `<nnnn>` | 4-digit suffix | Only for globally unique types (section 6) |

Storage accounts use the same parts with no separators: `st<scope><purpose><nnnn>`.

## 3. Reserved tokens

| Token | Meaning |
|---|---|
| `root` | The top of the hierarchy (`mg-root`, [ADR 0010](./adr/0010-top-management-group-mg-root.md)) |
| `platform` | The platform landing zone and everything the platform team runs |
| `landingzones`, `lz` | Application landing zones. `landingzones` is also the layer name used in its pipeline identities and GitHub Environment. `lz` is the short form, used in management groups and per-landing-zone identities and Environments |
| `products` | The shared landing zones that host Trislab's multi-tenant products |
| `cust-<code>` | A customer; `<code>` from the register in section 4 |
| `prdt-<code>` | A graduated product with its own landing zones; `<code>` from section 4 |
| `shr` | Owner code for stamps in the shared `products` landing zones (section 7.4) |
| `prod`, `sandbox` | Environment type. `sb` replaces `sandbox` **only** where a name would otherwise exceed its limit |
| `dev`, `test`, `uat`, `perf`, `demo`, `staging`, `pr<n>`, `prod` | Environment names inside a stamp (the `EnvironmentName` tag). `pr<n>` is a PR preview, e.g. `pr142` |
| `global` | Layer name used in identities and GitHub Environments |
| `experiments`, `decommissioned`, `regulated` | Management group purposes |
| `neu`, `itn` | Azure regions `northeurope`, `italynorth` |
| `euw8` | GCP region `europe-west8` ([ADR 0014](./adr/0014-gcp-region-europe-west8.md)) |

## 4. Owner codes

Every customer and every product gets a short **code** that is used in names instead of its full slug.

- 2–3 lowercase letters.
- Unique across customers **and** products together, and never equal to a reserved token (section 3).
- Never reused, even after the customer leaves.
- The full slug is used only where length doesn't matter: tags (`Customer`, `Product`), the tenant catalog and folder names in the repository. Display names follow principle 9 and use the code.
- A new code is added to this table in the same PR that onboards the customer or product.

| Full slug | Kind | Code | Status |
|---|---|---|---|
| `okna-capris` | Customer | `oc` | confirmed |
| `astra-group` | Customer | `asg` | confirmed |
| `vbs-lawyers` | Customer | `vbs` | confirmed |
| `rehabo` | Customer | `reh` | confirmed |
| `construction` | Product | `con` | confirmed |
| `hunting` | Product | `hnt` | confirmed |
| `website-trislab` | Product | `web` | confirmed |
| `manufacturing-logistics` | Product | `mfl` | confirmed |
| `erp-system` | Product | `erp` | confirmed |
| `reporting-service` | Product | `rpt` | confirmed |
| `customer-portal` | Product | `cpt` | confirmed |
| `application-x` | Product | `apx` | confirmed |

The 3-character cap comes from the Key Vault limit: `kv-prdt-con-sandbox-4821` is exactly 24 characters (section 6).

## 5. Resource-type abbreviations

Where the Cloud Adoption Framework has an abbreviation, it is used. `conn` is used instead of CAF's `con`, to avoid confusion with the product code `con`.

| Abbreviation | Resource | Cloud |
|---|---|---|
| `mg` | Management group | Azure |
| `sub` | Subscription | Azure |
| `rg` | Resource group | Azure |
| `fldr` | Folder | GCP |
| `prj` | Project (ID) | GCP |
| `vnet` | Virtual network | Azure |
| `vnetl` | Virtual network link of a private DNS zone | Azure |
| `nw` | Network Watcher | Azure |
| `vpc` | VPC network | GCP |
| `snet` | Subnet | Both |
| `nsg` | Network security group | Azure |
| `fw` | Firewall rule | GCP |
| `pip` | Public IP address | Azure |
| `vgw` | VPN gateway | Azure |
| `lgw` | Local network gateway | Azure |
| `conn` | VPN connection | Azure |
| `vpngw`, `rtr`, `tun` | HA VPN gateway, Cloud Router, VPN tunnel | GCP |
| `kv` | Key Vault | Azure |
| `st` | Storage account | Azure |
| `gcs` | Cloud Storage bucket | GCP |
| `log` | Log Analytics workspace | Azure |
| `ag` | Monitor action group | Azure |
| `afd`, `fde` | Front Door profile, Front Door endpoint | Azure |
| `cae` | Container Apps environment | Azure |
| `ca` | Container app | Azure |
| `aks` | AKS cluster | Azure |
| `func` | Function app / Cloud Function | Both |
| `run` | Cloud Run service | GCP |
| `psql` | PostgreSQL flexible server | Azure |
| `sql` | Cloud SQL instance | GCP |
| `spn` | Entra ID app registration / service principal (pipeline identity) | Azure |
| `id` | User-assigned managed identity | Azure |
| `sa` | Service account | GCP |
| `wif` | Workload Identity Federation pool / provider | GCP |
| `grp` | Entra ID group | Azure |
| `is` | Invoice section ([ADR 0011](./adr/0011-one-invoice-with-a-section-per-owner.md)) | Azure |

Names fixed by the cloud or by DNS are not changed: private DNS zones (`privatelink.*`), `GatewaySubnet`, and public DNS zones (named after the domain).

## 6. Globally unique names

Some names are shared by every customer of the cloud provider in the world, usually because the name becomes part of a public DNS name. These names get a **4-digit suffix** ([ADR 0002](./adr/0002-globally-unique-names-get-a-suffix.md)).

| Type | Why it is global | Example |
|---|---|---|
| `kv` Key Vault | `<name>.vault.azure.net` | `kv-cust-oc-sandbox-4821` |
| `st` Storage account | `<name>.blob.core.windows.net` | `stplatformtfstate1307` |
| `psql` PostgreSQL flexible server | `<name>.postgres.database.azure.com` | `psql-oc-con-prod-5530` |
| `func` Function app | `<name>.azurewebsites.net` | `func-shr-con-dev-2276` |
| `prj` GCP project ID | Global across GCP; a deleted ID can never be used again | `prj-cust-z-prod-euw8-4821` |
| `gcs` Cloud Storage bucket | Global bucket namespace | `gcs-platform-tfstate-1307` |

Rule of thumb: if the name ends up in a public hostname or is documented as "globally unique", it gets the suffix. A new type that is global is added to this table.

**How the suffix is made.**

- It is 4 random digits (`1000`–`9999`), created once per state (platform root, landing zone or stamp) by `random_integer` and stored in that state. Every global name in that state uses the same suffix.
- It has `keepers` on the region, so a region switch produces a new suffix. The new resource never waits for its soft-deleted predecessor to release the name.
- Recreating a landing zone or stamp creates a new state and therefore a new suffix.
- Nobody types the suffix by hand. It is read from state or from outputs.
- **The platform is the one exception.** Its suffix is picked once in the manual seed and shared by all its global names (`stplatformtfstate<nnnn>`, `kv-platform-<nnnn>`, `prj-platform-<nnnn>`, `gcs-platform-tfstate-<nnnn>`), because the state storage that would hold it is itself named with it ([09 section 5](./09-bootstrap.md#5-state-backend)).

**Length budget (Key Vault, 24 characters).**

| Name | Length |
|---|---|
| `kv-platform-1307` | 16 |
| `kv-products-sandbox-4821` | 24 |
| `kv-cust-oc-sandbox-4821` | 23 |
| `kv-cust-asg-sandbox-4821` | 24 |
| `kv-prdt-con-sandbox-4821` | 24 |

The Key Vault is the one landing zone name that leaves out the region token (section 7.3): with it, `kv-cust-asg-prod-neu-4821` would be 25 characters. It leaves out a landing zone's `<nn>` for the same reason. The suffix differs per state, so the Key Vaults of one owner's landing zones never clash, whether they are in different regions or numbered in the same region.

If a future scope doesn't fit, use `sb` for `sandbox` (e.g. `kv-cust-abc-sb-4821`), never a shorter suffix.

## 7. Names by layer

### 7.1 L0 Global

| What | Name |
|---|---|
| Plan / apply identity | `spn-global-plan`, `spn-global-apply` |
| Front Door failover profile | `afd-global` |
| Resource group for edge failover | `rg-global-edge` |
| Public DNS zones | the domain itself (e.g. `customer-domain.com`) |
| Neon / Upstash projects | `<stamp-code>`, e.g. `oc-con-prod` (stamp codes are unique across the repository) |

### 7.2 L1 Platform landing zone

| What | Azure | GCP |
|---|---|---|
| Top of hierarchy | `mg-root` (display name "Trislab") | the organization |
| Platform | `mg-platform` | `fldr-platform` |
| Landing zones | `mg-landingzones`, `mg-lz-prod`, `mg-lz-prod-regulated`, `mg-lz-sandbox` | `fldr-landingzones`, `fldr-lz-prod`, `fldr-lz-sandbox` |
| Other | `mg-experiments`, `mg-decommissioned` | — |
| Platform subscriptions / projects | `sub-platform` (MVP), later `sub-platform-connectivity`, `sub-platform-management`, `sub-platform-apps` | `prj-platform-1307` |
| State | `rg-platform-state`, `stplatformtfstate1307`; containers `tfstate-global`, `tfstate-platform`, `tfstate-lz`, `tfstate-stamps`; key = root name, e.g. `governance.tfstate`, `cust-oc-prod-neu.tfstate`, `cust-oc-prod-neu/construction.tfstate` | `gcs-platform-tfstate-1307` |
| Private DNS | `rg-platform-dns`, holding the `privatelink.*` zones ([ADR 0020](./adr/0020-landing-zone-links-private-dns-zones.md)) | — |
| Hub network | `rg-hub-neu`, `vnet-hub-neu`, `vgw-hub-neu`, `pip-vgw-hub-neu`, `conn-hub-neu-to-gcp` | `vpc-hub`, `snet-hub-euw8`, `rtr-hub-euw8`, `vpngw-hub-euw8` |
| Management | `log-platform`, `ag-finops`, `kv-platform-1307` | — |
| Pipeline identities | `spn-platform-plan`, `spn-platform-apply`, `spn-landingzones-plan`, `spn-landingzones-apply` | `sa-platform-plan`, `sa-platform-apply`, `sa-landingzones-apply`; pool `wif-github` |
| Invoice sections for Trislab's own costs | `is-platform`, `is-products` | — |
| Portal identity | `id-backstage` | — |
| Human groups | `grp-devops`, `grp-platform-admins`, `grp-regulated-admins` | — |

### 7.3 L2 Application landing zones

A landing zone name is `<scope>-<envtype>-<region>[-<nn>]`, with the region token from section 3 ([ADR 0015](./adr/0015-one-landing-zone-one-region.md)). An owner has one landing zone per environment type per region, and starts with `neu` (GCP: `euw8`). A second landing zone of the same owner, environment type and region is created only when a landing zone setting (`archetype`, `budget`, `access`, Key Vault, `observability`) has to differ. It gets `<nn>` = `02`, `03`, …, e.g. `cust-vbs-prod-neu-02`. The first one has no number, and numbers are never reused. The name is also the landing zone's file name (`landing-zones/<lz>.yaml`), its folder under `stamps/`, and its GitHub Environment `lz-<lz>`.

| What | Pattern | Example (customer `oc`, sandbox) |
|---|---|---|
| Landing zone | `<scope>-<envtype>-<region>[-<nn>]` | `cust-oc-sandbox-neu` (second one: `cust-oc-sandbox-neu-02`) |
| Subscription | `sub-<lz>` | `sub-cust-oc-sandbox-neu` |
| GCP project | `prj-<lz>-<nnnn>` | `prj-cust-oc-sandbox-euw8-4821` (29 of 30; `prj-products-sandbox-euw8-4821` is exactly 30) |
| Resource groups ([ADR 0022](./adr/0022-landing-zone-resource-groups-per-purpose.md)) | `rg-<lz>-network`, `rg-<lz>-security`, `rg-<lz>-monitoring` (only with a dedicated workspace) | `rg-cust-oc-sandbox-neu-network` |
| Spoke network | `vnet-<lz>` (the region is already in `<lz>`) | `vnet-cust-oc-sandbox-neu` |
| Network Watcher | `nw-<lz>`, in `rg-<lz>-network` | `nw-cust-oc-sandbox-neu` |
| Key Vault | `kv-<scope>-<envtype>-<nnnn>`, no region token and no `<nn>` (section 6) | `kv-cust-oc-sandbox-4821` |
| Dedicated workspace (regulated) | `log-<lz>` | `log-cust-oc-prod-neu` |
| Budget | `budget-<lz>` | `budget-cust-oc-sandbox-neu` |
| Invoice section | `is-<scope>`; shared products and every `prdt-*` landing zone use `is-products` | `is-cust-oc` |
| Plan / deploy identity | `spn-lz-<lz>-plan`, `spn-lz-<lz>-deploy` | `spn-lz-cust-oc-sandbox-neu-deploy` |
| GCP deploy service account | `sa-lz-<scope>-<envtype>-deploy`, no region token and no `<nn>` (it is unique within its project) | `sa-lz-cust-oc-sandbox-deploy` (28 of 30) |
| Customer admin group | `grp-<scope>-admins` | `grp-cust-oc-admins` |

All landing zone names in use:

| Owner | Sandbox | Prod |
|---|---|---|
| Shared products | `products-sandbox-neu` | `products-prod-neu` |
| Customer | `cust-<code>-sandbox-neu` | `cust-<code>-prod-neu` |
| Graduated product | `prdt-<code>-sandbox-neu` | `prdt-<code>-prod-neu` |

Any of these can get a `-<nn>` sibling in the same region under the rule above.

`02-architecture.md` uses the placeholder codes `x`, `y`, `z`, `c` and `p` (e.g. `cust-x-prod-neu`, `prdt-p-prod-neu`).

### 7.4 L3 Stamps

A stamp has two names:

- **Folder name**: readable, in the repository at `stamps/<lz>/<folder>/`, e.g. `construction-dev`, `construction-shared-01`, `website-trislab`.
- **Stamp code**: short, used in every resource name: `<owner-code>-<product-code>-<envname>[-<nn>]`.
  - `<owner-code>` is the customer's code, `shr` for the shared products landing zones, or omitted for a graduated product (its owner and product are the same).
  - `<nn>` numbers several stamps of the same owner, product and environment (`01`, `02`, …), in one landing zone or across the owner's landing zones (in different regions, or `-<nn>` landing zones in one region).

| Landing zone / folder | Stamp code |
|---|---|
| `products-prod-neu/construction-shared-01` | `shr-con-prod-01` |
| `products-prod-neu/website-trislab` | `shr-web-prod` |
| `products-sandbox-neu/construction-dev` | `shr-con-dev` |
| `cust-oc-sandbox-neu/construction-test` | `oc-con-test` |
| `cust-oc-prod-neu/construction` | `oc-con-prod` |
| `prdt-con-prod-neu/construction` | `con-prod` |

Resources inside a stamp:

| What | Pattern | Example |
|---|---|---|
| Resource group | `rg-<stamp>` | `rg-oc-con-prod` |
| Container Apps infrastructure resource group (created by Azure for the environment) | `rg-<stamp>-infra` | `rg-oc-con-prod-infra` |
| Subnet / NSG | `snet-<stamp>`, `nsg-<stamp>` | `snet-oc-con-prod` |
| Container Apps environment | `cae-<stamp>` | `cae-oc-con-prod` |
| Container app | `ca-<stamp>-<app>` | `ca-oc-con-prod-web` |
| AKS cluster | `aks-<stamp>` | `aks-oc-con-prod` |
| Function app | `func-<stamp>-<nnnn>` | `func-shr-con-dev-2276` |
| PostgreSQL server | `psql-<stamp>-<nnnn>` | `psql-oc-con-prod-5530` |
| Storage account | `st<stamp without hyphens><nnnn>` | `stocconprod5530` |
| Workload identity | `id-<stamp>-workload` | `id-oc-con-prod-workload` |
| App-deploy identity | `id-<stamp>-appdeploy` (GCP: `sa-<stamp>-appdeploy`) | `id-oc-con-prod-appdeploy` |
| Secret in the landing zone Key Vault | `<stamp>-<name>` | `oc-con-prod-session-key` |
| Cloud Run service (GCP) | `run-<stamp>-<app>` | `run-z-con-prod-web` |

No region token: a stamp runs in its landing zone's region, and the landing zone name already carries it (principle 5).

## 8. GitHub names

| What | Name |
|---|---|
| Environments in `tl-cloud-infrastructure` | `global`, `platform`, `landingzones`, `lz-<lz>` (e.g. `lz-cust-oc-prod-neu`) |
| Secrets handed to stamps in `lz-<lz>` | `<NAME>_<STAMP>`, where `<STAMP>` is the stamp code in capitals with `_` for `-`: `NEON_KEY_OC_CON_PROD`, `REDIS_URL_OC_CON_PROD`. One per landing zone: `GHCR_PULL_TOKEN`. Each has a variable `<secret>_VERSION` ([ADR 0026](./adr/0026-vendor-credentials-through-lz-environment.md)) |
| Environments in app repositories | `dev`, `test`, `prod` (as the app's promotion stages) |
| GitHub Apps | `tl-landingzones-apply`, `tl-landingzones-plan` ([ADR 0019](./adr/0019-github-app-for-landing-zone-environments.md)), `tl-global-apply` ([ADR 0026](./adr/0026-vendor-credentials-through-lz-environment.md)). App names are unique across GitHub, so they keep the `tl-` prefix |
| Repositories | unchanged: `tl-cloud-infrastructure`, `tl-platform`, `tl-template-*`, `tl-platform-backstage`. These are GitHub names, not cloud resources |

## 9. Tags and labels

Every resource carries these four tags (Azure, PascalCase) or labels (GCP, snake_case) (N5).

| Azure tag | GCP label | Value |
|---|---|---|
| `Product` | `product` | Product full slug (e.g. `construction`), or `platform` for platform resources |
| `Customer` | `customer` | Customer full slug (e.g. `okna-capris`), or `trislab` for Trislab's own products and the platform |
| `EnvironmentType` | `environment_type` | `prod` or `sandbox` |
| `EnvironmentName` | `environment_name` | `dev`, `test`, `uat`, `perf`, `demo`, `staging`, `pr<n>` or `prod` |

Tag values use full slugs, not codes, so cost reports and log queries are readable.

Stamp templates set one more tag, on container apps only: `SizingCaps`, the caps that app CI checks `platform.yaml` against, e.g. `cpu=1;memory=2Gi;minreplicas=0;maxreplicas=10;profiles=Consumption` ([06 section 6.5](./06-stamp-templates.md#65-sizing-caps-and-platformyaml)). It is not mandatory and not used for cost reports.

## 10. Limits

| Type | Length | Characters | Unique within |
|---|---|---|---|
| `mg` (ID) | 1–90 | letters, digits, `-_.()` | Tenant |
| `rg` | 1–90 | letters, digits, `-_.()` | Subscription |
| `vnet` | 2–64 | letters, digits, `-_.` | Resource group |
| `kv` | 3–24 | letters, digits, `-`; starts with a letter; no `--` | **All of Azure** (including soft-deleted vaults) |
| `st` | 3–24 | lowercase letters and digits only | **All of Azure** |
| `psql` | 3–63 | lowercase letters, digits, `-` | **All of Azure** |
| `func` | 2–60 | letters, digits, `-` | **All of Azure** |
| `log` | 4–63 | letters, digits, `-` | Resource group |
| `cae` | 2–60 | lowercase letters, digits, `-` | Resource group |
| `ca` | 2–32 | lowercase letters, digits, `-`. With the longest stamp code (18), an app name has at most 10 characters | Resource group |
| Key Vault secret | 1–127 | letters, digits, `-` | Key Vault |
| `aks` | 1–63 | letters, digits, `-_` | Resource group |
| `id` | 3–128 | letters, digits, `-_` | Resource group |
| `prj` (ID) | 6–30 | lowercase letters, digits, `-`; starts with a letter | **All of GCP**, forever |
| `gcs` | 3–63 | lowercase letters, digits, `-_.` | **All of GCP** |
| `sa` (ID) | 6–30 | lowercase letters, digits, `-` | Project |
| `vpc`, `snet`, `fw` | 1–63 | lowercase letters, digits, `-` | Project |

## 11. Enforcement

- An OPA/conftest rule runs on every plan. It checks each new resource name against the pattern for its type (sections 5–7), its length limit (section 10), and that the owner code exists in section 4.
- Azure Policy (deny) and the same OPA run check that the four tags in section 9 are present, with allowed values for `EnvironmentType`.
- Names are generated by the `landing-zone` module and the stamp templates from `lz.yaml` and `stamp.yaml`. Nobody writes a resource name by hand.
