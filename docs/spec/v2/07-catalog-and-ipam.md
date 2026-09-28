# 07 — Tenant catalog and IP plan

> Part of [spec v2](./README.md). Specifies the two data files in `catalog/`: the tenant catalog `tenants.yaml` and the IP plan `ipam.yaml`. It expands [02 section 1](./02-architecture.md#rules) rule 5 and [02 section 4](./02-architecture.md#4-network). All names follow [`03-naming-conventions.md`](./03-naming-conventions.md).

## 1. Scope

The `catalog/` folder holds data, not OpenTofu roots. Nothing is applied from it directly. The roots that read it are planned again whenever it changes ([`08-pipeline.md`](./08-pipeline.md) section 2).

| File | Holds | Read by | Changed by |
|---|---|---|---|
| `tenants.yaml` | Public DNS domains, and every tenant with its stamp and hostnames | `global/edge` (L0) and the stamp templates (L3) | PRs only ([ADR 0012](./adr/0012-tenant-catalog-stays-yaml.md)). The developer portal opens the same PRs later (F10) |
| `ipam.yaml` | Address ranges for every hub, landing zone spoke and stamp subnet | `platform/*/connectivity` (L1), the `landing-zone` module (L2) and the stamp templates (L3) | PRs only, in the same PR as the hub, `lz.yaml` or `stamp.yaml` that uses the range |

Abbreviations used in this file:

| Abbreviation | Meaning |
|---|---|
| FQDN | Fully qualified domain name, e.g. `www.trislab.com` |
| CIDR | An address range written as start address and prefix length, e.g. `10.16.0.0/20` |
| IPAM | IP address management: the address plan in `ipam.yaml` |

## 2. `tenants.yaml` schema

```yaml
# catalog/tenants.yaml
domains:
  - name: trislab.com
    owner: trislab
  - name: astra-group.example        # the real domain is set when the customer is onboarded
    owner: astra-group

tenants:
  - name: website-trislab
    customer: trislab
    stamp: products-prod-neu/website-trislab
    hostnames:
      - { fqdn: trislab.com, app: web }
      - { fqdn: www.trislab.com, app: web }
  - name: website-trislab
    customer: trislab
    stamp: products-sandbox-neu/website-trislab-staging
    hostnames:
      - { fqdn: staging.trislab.com, app: web }
  - name: astra-group
    customer: astra-group
    stamp: cust-asg-prod-neu/construction
    hostnames:
      - { fqdn: astra-group.example, app: web }
  - name: astra-group
    customer: astra-group
    stamp: cust-asg-sandbox-neu/construction-dev
    hostnames:
      - { fqdn: dev.astra-group.example, app: web }
```

An entry in `tenants` is **one tenant on one stamp**. A customer with dev, test and prod stamps has three entries with the same `name`.

### 2.1 `domains`

| Field | Required | Values | Rule |
|---|---|---|---|
| `name` | yes | A registered domain | Unique. `global/edge` creates one Cloudflare zone and one Azure DNS zone for it |
| `owner` | yes | A customer full slug from [03 section 4](./03-naming-conventions.md#4-owner-codes), or `trislab` | Only this owner's tenants may use hostnames in the domain (section 3) |

### 2.2 `tenants`

| Field | Required | Values | Rule |
|---|---|---|---|
| `name` | yes | Lowercase letters, digits and `-`, at most 40 characters | Unique within one stamp. Becomes part of `PLATFORM_TENANTS` on the stamp's apps ([06 section 6.3](./06-stamp-templates.md#63-apps-and-the-app-deploy-identity)) |
| `customer` | yes | A customer full slug, or `trislab` | For a stamp in a customer landing zone, the landing zone's owner. For a stamp in a `products-*` or `prdt-*` landing zone, any customer or `trislab` |
| `stamp` | yes | `<lz>/<folder>` | The stamp folder must exist under `stamps/` |
| `hostnames` | no | List of `{ fqdn, app }` | A tenant with no hostnames is still passed to the stamp |
| `hostnames[].fqdn` | yes | Lowercase FQDN | Unique across the whole catalog. Inside a domain from `domains` (section 3) |
| `hostnames[].app` | yes | An `apps[].name` of the stamp | The app must have `ingress: external` ([06 section 3.3](./06-stamp-templates.md#33-aca-app-fields)) |

The tenancy rules come from the stamp: a `dedicated` stamp has exactly one entry, and a `shared` stamp has zero or more ([06 section 7](./06-stamp-templates.md#7-tenancy)).

## 3. Hostname rules

| Rule | Example |
|---|---|
| A hostname belongs to the longest domain in `domains` that it ends with. That domain's zone gets its records | `dev.astra-group.example` → zone `astra-group.example` |
| The domain's `owner` is the tenant's `customer`, or `trislab`. A customer's domain never serves another customer's tenant | `astra-group.example` can't be used by an Okna Capris tenant |
| A production hostname is chosen freely inside the domain. By default it is the domain root (F8) | `astra-group.example` |
| A sandbox hostname is the matching production hostname with `<environment>.` in front, where `<environment>` is the stamp's `environment` | `dev.astra-group.example`, `test.astra-group.example`, `staging.trislab.com` |
| A PR preview stamp gets `pr<n>.` in front of the production hostname, added by the pipeline with the stamp ([06 section 9](./06-stamp-templates.md#9-ephemeral-stamps)) | `pr142.trislab.com` |
| A customer with several products uses one subdomain per product in production, and the same rule for sandbox | `portal.okna-capris.si`, `dev.portal.okna-capris.si` |

Every hostname of a stamp in a sandbox landing zone is behind Cloudflare Zero Trust, through the wildcard access policy in `global/edge` (N7). Production hostnames are public.

## 4. Who reads the tenant catalog

| Reader | Reads | Creates |
|---|---|---|
| `global/edge/zones.tf` | `domains` | One Cloudflare zone and one Azure DNS zone per domain. Their nameservers are listed at the registrar, which is the one manual step per domain (N11) |
| `global/edge/records.tf` | `tenants[].stamp`, `hostnames` | The hostname and `asuid` records in both providers, pointing at the stamp's environment, looked up by name ([ADR 0027](./adr/0027-global-edge-writes-stamp-dns-records.md)) |
| `global/edge/zero-trust.tf` | Hostnames of stamps in sandbox landing zones | Cloudflare Access coverage for them |
| `global/edge/front-door.tf` | Hostnames of stamps in prod landing zones | Front Door origins and routes for the failover mirror (N7) |
| The stamp's generated `main.tf` | The entries whose `stamp` is this stamp | The template's `tenants` input: hostname bindings ([06 section 6.6](./06-stamp-templates.md#66-hostnames)) and `PLATFORM_TENANTS` |

A stamp sees only its own entries. `global/edge` sees all of them.

## 5. `ipam.yaml` schema

```yaml
# catalog/ipam.yaml
pools:
  hubs: 10.0.0.0/12               # Azure hubs from 10.0.0.0/13, GCP hubs from 10.8.0.0/13
  prod: 10.16.0.0/12
  sandbox: 10.32.0.0/12

hubs:
  - name: vnet-hub-neu
    cloud: azure
    region: northeurope
    cidr: 10.0.0.0/20
    subnets:
      GatewaySubnet: 10.0.0.0/27

landing_zones:
  - name: products-prod-neu
    cidr: 10.16.0.0/20
    stamps:
      website-trislab: 10.16.0.0/27
  - name: products-sandbox-neu
    cidr: 10.32.0.0/20
    stamps:
      website-trislab-staging: 10.32.0.0/27
```

| Field | Required | Values | Rule |
|---|---|---|---|
| `pools.hubs`, `pools.prod`, `pools.sandbox` | yes | CIDR | Fixed. Changing a pool is a new ADR |
| `hubs[].name` | yes | `vnet-hub-<code>` (GCP: `snet-hub-<code>`) | Equal to the hub's resource name ([03 section 7.2](./03-naming-conventions.md#72-l1-platform-landing-zone)) |
| `hubs[].cloud` | yes | `azure`, `gcp` | Azure hubs from `10.0.0.0/13`, GCP hubs from `10.8.0.0/13` |
| `hubs[].region` | yes | An allowed region | Matches the region code in `name` |
| `hubs[].cidr` | yes | A /20 | Inside the cloud's half of `pools.hubs` |
| `hubs[].subnets` | no | Map of subnet name → CIDR | Inside the hub's `cidr`. `GatewaySubnet` is a /27 at the start of the hub |
| `landing_zones[].name` | yes | A landing zone name | Equal to `landing-zones/<name>.yaml` |
| `landing_zones[].cidr` | yes | A /20 | Inside `pools.prod` or `pools.sandbox`, matching the landing zone's environment type. Equal to `network.spoke_cidr` in its `lz.yaml` ([05 section 2](./05-landing-zones.md#2-lzyaml-schema)) |
| `landing_zones[].stamps` | no | Map of stamp folder → CIDR | Inside the landing zone's `cidr`. Equal to `network.subnet_cidr` in the stamp's `stamp.yaml` ([06 section 3.1](./06-stamp-templates.md#31-fields-every-template-has)) |

A range is reserved by being in the file. There is no separate "free" list: a free range is one that no entry covers.

## 6. Address plan

### 6.1 Pools

| Pool | Range | Holds | Room for |
|---|---|---|---|
| Azure hubs | `10.0.0.0/13` | One /20 per Azure region | 128 regions |
| GCP hubs | `10.8.0.0/13` | One /20 per GCP region | 128 regions |
| Prod landing zones | `10.16.0.0/12` | One /20 per prod landing zone | 256 landing zones |
| Sandbox landing zones | `10.32.0.0/12` | One /20 per sandbox landing zone | 256 landing zones |

The prod and sandbox pools are what the stamps' NSG deny rules use to keep sandbox and production apart ([06 section 6.2](./06-stamp-templates.md#62-network), [ADR 0025](./adr/0025-stamp-nsg-carries-isolation-rules.md)). A landing zone's range must therefore always come from the pool of its environment type.

### 6.2 Ranges in the plan

Each range is added to `ipam.yaml` in the PR that creates what uses it. This table is the plan for the owners in [04](./04-repository-structure.md#4-owners-and-environments-covered), so that ranges stay in the same order as they are added.

| Range | For | Added in |
|---|---|---|
| `10.0.0.0/20` | `vnet-hub-neu` | Platform landing zone ([`10-roadmap.md`](./10-roadmap.md)) |
| `10.8.0.0/20` | `snet-hub-euw8` | The first GCP customer ([ADR 0008](./adr/0008-gcp-built-on-first-customer.md)) |
| `10.16.0.0/20`, `10.32.0.0/20` | `products-prod-neu`, `products-sandbox-neu` | Platform landing zone and product pilot |
| `10.16.16.0/20`, `10.32.16.0/20` | `cust-oc-prod-neu`, `cust-oc-sandbox-neu` | When Okna Capris is onboarded |
| `10.16.32.0/20`, `10.32.32.0/20` | `cust-asg-prod-neu`, `cust-asg-sandbox-neu` | Customer pilot |
| `10.16.48.0/20`, `10.32.48.0/20` | `cust-vbs-prod-neu`, `cust-vbs-sandbox-neu` | When VBS Lawyers is onboarded |
| `10.16.64.0/20`, `10.32.64.0/20` | `cust-reh-prod-euw8`, `cust-reh-sandbox-euw8` | When Rehabo is onboarded, with GCP |

A new owner takes the next free /20 in each pool. A new region's hub takes the next free /20 in its cloud's half of the hub pool, e.g. `10.0.16.0/20` for a second Azure region ([05 section 5](./05-landing-zones.md#5-adding-a-region)).

### 6.3 Stamp subnets

| Rule | Detail |
|---|---|
| Size | A /27 when every app runs on `Consumption`. A /26 or larger when a Dedicated workload profile is used, because each Dedicated node takes an address ([06 section 6.2](./06-stamp-templates.md#62-network)). An AKS stamp takes a /23 ([02 section 4](./02-architecture.md#4-network)) |
| Placement | The lowest free block of the right size in the landing zone's /20, aligned to its size |
| Fixed | A stamp's subnet can't change without recreating its environment, so the reservation stays for the stamp's whole life |
| Ephemeral stamps | Get a /27 like any stamp, in the PR that creates them. The pipeline picks the lowest free block ([06 section 9](./06-stamp-templates.md#9-ephemeral-stamps)) |

## 7. Checks before apply

These run at plan time, so a wrong catalog fails in the PR, before anything is created. `policy/catalog.rego` runs in the same conftest step as the naming and tag rules ([`08-pipeline.md`](./08-pipeline.md) section 3).

| Check | Where |
|---|---|
| Both files match their schema | `policy/catalog.rego` |
| Every `tenants[].stamp` folder exists, and every `hostnames[].app` is an app of that stamp with `ingress: external` | `policy/catalog.rego` |
| Every FQDN is unique, lies inside a declared domain, and that domain's owner is the tenant's customer or `trislab` | `policy/catalog.rego` |
| A sandbox hostname starts with `<environment>.` | `policy/catalog.rego` |
| A tenant on a stamp in a customer landing zone has that customer as `customer` | `policy/catalog.rego` |
| No two ranges in `ipam.yaml` overlap, except a stamp inside its landing zone and a subnet inside its hub | `policy/catalog.rego` |
| Every range is inside its pool, and every landing zone range is in the pool of its environment type | `policy/catalog.rego` |
| `spoke_cidr` in `lz.yaml` equals the landing zone's range | `landing-zone` module (precondition, [05 section 3](./05-landing-zones.md#3-checks-before-apply)) |
| `subnet_cidr` in `stamp.yaml` equals the stamp's range | Stamp template (precondition, [06 section 4](./06-stamp-templates.md#4-checks-before-apply)) |
| A hub's `cidr` equals its range | `platform/*/connectivity` (precondition in `hub-<code>.tf`) |
| A dedicated stamp has exactly one tenant | Stamp template (precondition) |

## 8. Changing the catalog

| Change | PR contents | Applies, in order |
|---|---|---|
| **New stamp with hostnames** | `stamp.yaml` and `main.tf`, the stamp's range in `ipam.yaml`, its entries in `tenants.yaml` | Stamp (hostnames not yet bound), `global`, stamp again ([ADR 0027](./adr/0027-global-edge-writes-stamp-dns-records.md), [`08-pipeline.md`](./08-pipeline.md) section 6) |
| **New tenant on a shared stamp** | An entry in `tenants.yaml` | `global`, then the stamp |
| **New customer domain** | An entry in `domains` | `global`. Then the customer delegates the nameservers at their registrar |
| **Move a hostname to another stamp** (graduation, region move) | Change `stamp` of the entry, or move the hostname to the new stamp's entry | `global` (records now point at the new stamp), then the new stamp (binds), then the old stamp (unbinds). The old stamp is removed in a later PR ([06 section 10](./06-stamp-templates.md#10-lifecycle)) |
| **Remove a hostname or tenant** | Delete it from `tenants.yaml` | The stamp (unbinds) and `global` (records deleted), in either order |
| **Destroy a stamp** | Delete its folder, its entries and its range | The stamp's destroy, then `global`. The range is free once the destroy is applied |
| **Decommission a landing zone** | Its range stays in `ipam.yaml` until the subscription is deleted | The range is removed in the clean-up PR of step 5 in [02 section 3](./02-architecture.md#decommissioning) |

## 9. Decisions and open questions

| Item | Affects | Status |
|---|---|---|
| [ADR 0012](./adr/0012-tenant-catalog-stays-yaml.md): the tenant catalog stays a YAML file in the repository | Section 1 | accepted |
| [ADR 0027](./adr/0027-global-edge-writes-stamp-dns-records.md): `global/edge` writes every stamp's DNS records | Sections 4 and 8 | accepted |

The questions are tracked in [`TODO.md`](./TODO.md#open-questions).
