# ADR 0027: `global/edge` writes every stamp's DNS records, and the stamp only binds its hostnames

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Before a stamp can answer on `app.okna-capris.si`, two DNS records must exist: one that points the name at the stamp, and one (`asuid.app.okna-capris.si`) that proves to Azure we own the name. Only then does Azure let the stamp bind the hostname and issue its certificate. It's like a new shop that needs a sign on the street and a registration at the town hall before it can open: someone has to put up the sign, and the town hall needs to see the paperwork first.

The spec named two different owners for these records: the stamp template ([02 section 5](../02-architecture.md#5-stamps)) and `global/edge` ([04](../04-repository-structure.md)). The stamp knows its address, but holds no DNS credentials. `global` holds the DNS credentials and the catalog, but doesn't know the stamp's address until the stamp exists.

Example: the stamp `oc-con-prod` creates `cae-oc-con-prod`. The catalog maps `app.okna-capris.si` to its `web` app. The zone `okna-capris.si` is shared by the customer's sandbox and prod landing zones.

## The decision

`global/edge` writes every DNS record in Cloudflare and Azure DNS, including the `asuid` records, from the catalog. It finds each stamp's address and verification ID by looking up the stamp's Container Apps environment by name. The stamp template writes no DNS records: it binds a hostname only once its `asuid` record resolves.

Whichever side runs first skips what it can't do yet, and finishes on its next apply. The pipeline runs that apply after the other side's apply (specified in `08-pipeline.md`).

## What this means in practice

- Cloudflare and Azure DNS credentials stay in the `global` Environment only. No landing zone gets a DNS token, and a sandbox stamp can't change a prod record in a zone the two share.
- All of the edge (records, WAF, Zero Trust, the Front Door mirror) is in one layer, generated from the catalog, as [02 section 1](../02-architecture.md#rules) says.
- Creating a stamp with hostnames takes three applies from one PR: the stamp (hostnames not yet bound), `global` (records written), and the stamp again (hostnames bound). Nobody has to copy an address or an ID by hand.
- Removing a hostname from the catalog unbinds it in the stamp and deletes its records in `global`, in either order.
- If a stamp's environment is recreated, its address and verification ID change. The next `global` apply updates the records, and the next stamp apply binds the hostnames again. The plan that recreates the environment already stops review ([06 section 8](../06-stamp-templates.md#8-versions-and-upgrades)).

## Options we did not choose

| Option | Why not |
|---|---|
| The stamp writes its own records, with a Cloudflare token and an Azure DNS role per landing zone | DNS credentials in every landing zone Environment. A customer's sandbox and prod stamps share one zone, so a sandbox stamp could change a prod record. The edge would be split over two layers |
| `global` reads the stamp's address from the stamp's state | `spn-global-apply` would need read access to every landing zone's state in `tfstate-stamps`, which holds more than addresses |
| An engineer copies the address and verification ID into the catalog | A manual step for every stamp, and wrong as soon as an environment is recreated (N11) |

## Technical details

- **Lookup.** `global/edge/records.tf` runs one Azure Resource Graph query for `Microsoft.App/managedEnvironments` named `cae-<stamp>` for every stamp in the catalog. It reads `properties.defaultDomain`, `properties.staticIp` and `properties.customDomainConfiguration.customDomainVerificationId`. A stamp with no environment yet gets no records.
- **Rights.** A custom role, **"Edge stamp reader"**, allows only `Microsoft.App/managedEnvironments/read`. `platform/azure/governance` defines it, assignable at `mg-landingzones`. The `landing-zone` module assigns it on its subscription to `spn-global-plan` and `spn-global-apply`, and it joins the fixed set of roles `spn-landingzones-apply` may assign. It shows no secrets and no app settings, so N4 holds.
- **Records per hostname**, in both Cloudflare and Azure DNS:

  | Record | Name | Value |
  |---|---|---|
  | CNAME, or A for a zone apex | `<hostname>` | `ca-<stamp>-<app>.<defaultDomain>`; for an apex, `staticIp` (Cloudflare flattens the CNAME, Azure DNS gets the A record) |
  | TXT | `asuid.<hostname>` | `customDomainVerificationId` |

- **Binding.** The template looks up `asuid.<hostname>` with the `dns` provider and binds the hostname only when the record holds the environment's verification ID. **To check in the pilot:** that the lookup of a name that doesn't exist yet returns an empty result instead of failing the plan.
- **To check in the pilot:** whether Container Apps issues a managed certificate while Cloudflare proxies the hostname. If it doesn't, the stamp binds with a Cloudflare origin certificate, handed over as in [ADR 0026](./0026-vendor-credentials-through-lz-environment.md).
- **To check in the pilot:** whether the verification ID is the same for every environment in a subscription. If it is, `global` needs one lookup per landing zone instead of one per stamp.
- **Front Door** uses the same lookup for the origins of production stamps.
- **GCP:** `cloudrun-app` stamps are looked up the same way with a read-only role on their project, specified with `cloudrun-app`.
- **Spec changes:** [02 sections 5 and 6](../02-architecture.md#5-stamps) (the stamp's DNS bullet, the `dns-records` building block, the global identities), [04](../04-repository-structure.md) (`global/edge/records.tf`, `custom-roles.tf`), [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 8, and [06 sections 2, 6.1, 6.6 and 10](../06-stamp-templates.md#66-hostnames).
