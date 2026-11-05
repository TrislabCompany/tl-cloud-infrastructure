---
name: stamp-create
description: Create a stamp (one Environment of an app, e.g. dev, staging or prod) in an existing landing zone of tl-cloud-infrastructure — write stamps/<lz>/<folder>/stamp.yaml, generate main.tf with the pinned tl-platform generator, lock the providers, reserve its /27 in catalog/ipam.yaml and add its tenant with the default hostname <env>-<product>.trislab.com (public or protected) to catalog/tenants.yaml — as one PR opened with the user's own gh credentials. Use when the user asks to create, add, provision, deploy infrastructure for or set up a stamp, an environment such as dev, test, staging, demo or prod for an app, or a production stamp.
metadata:
  owner: infrastructure
---

# stamp-create

One PR, applied in three passes:
1. **The stamp:** the Container Apps environment and apps, with hostnames not yet bound.
2. **`global`:**
   - `global/edge` writes the hostname's proxied CNAME, its `asuid` TXT and the zone's origin certificate;
   - `global/github` creates the app repository's GitHub Environment `<environment>`, with its variables. In a prod landing zone it adds the reviewers `devops` and the product's team.
3. **The stamp again:** binds the hostname.

The landing zone must be applied first: a stamp needs its Environment `lz-<lz>`.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required | Rule |
| --- | --- | --- |
| `lz` | yes | An `active`, non-experiment landing zone in `landing-zones/` |
| `product` | yes | An `active` product slug in `catalog/owners.yaml`, such as `corporate-site` |
| `environment` | yes | In a prod landing zone, only `prod`. In a sandbox one: `dev`, `test`, `uat`, `perf`, `demo`, `staging`, or `pr<n>` (which needs `ttl`) |
| `apps` | yes | Each with `name` (2–10 characters), `repo` (an `active` entry in `catalog/repos.yaml`), `ingress` (`external`, `internal` or `none`), `port`, and `caps` (`cpu`, `memory`, `max_replicas`). Default: copy the apps of the product's existing stamp, for example `stamps/products-sandbox-neu/corporate-site-dev/stamp.yaml` |
| `tenancy` | yes | `dedicated` (default, and the only choice in a customer landing zone) or `shared` |
| `version` | no | The `aca-app` release. Default: the newest tag `aca-app/v*` in `tl-platform`. Show it next to the version the product's other stamps pin |
| `access` | no | `public` or `protected`, for the default hostname. In a sandbox landing zone it is always `protected` (Cloudflare Access). In prod, default `protected` for the stamp's own `<env>-<product>` hostname: only the product's real domain is public. See [Access](#access) |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)). `pwsh` and `tofu` are needed, and `tl-platform` must be cloned next to this repository (`../tl-platform`).
2. **Preconditions.** Stop with the reason when one fails.
   - `landing-zones/<lz>.yaml` on `origin/main` is `active` and not `archetype: experiment`.
   - The Environment exists: `gh api repos/TrislabCompany/tl-cloud-infrastructure/environments/lz-<lz> --jq .name`. Otherwise the landing zone isn't applied yet: point to its PR, and stop.
   - The product and each app's repository are active in the catalog.
   - In a prod landing zone the environment is `prod`, and in a sandbox one it isn't.
   - The folder doesn't exist and isn't in `catalog/ipam.yaml`.
3. **Compute:**
   - **Folder:** `<product>-<environment>`, or `<product>` alone in a prod landing zone, for example `stamps/products-prod-neu/corporate-site`.
   - **Stamp code:** `<owner code>-<product code>-<environment>`. `<owner code>` is `shr` in `products-*` and the customer's code in `cust-*`, and `<product code>` is the product's `code` in `owners.yaml`. Example: `shr-web-prod`.
   - **Range:** `python .agents/skills/_shared/ipam.py stamp <lz>` gives the lowest free aligned /27. A Dedicated workload profile needs a /26 or larger (`--prefix 26`). This template allows only `Consumption`.
   - **Default hostname** (first app with `ingress: external`):
     - in `products-*` and `prdt-*`: `<environment>-<product>.trislab.com`;
     - in `cust-<code>-*`: `<environment>-<product>-<customer slug>.trislab.com`;
     - the first label is at most 63 characters, and the hostname must not already be in `catalog/tenants.yaml`.
     - Every other external app gets a derived hostname (`-<app>` added to the first label). `global/edge` makes it; it is never written in `tenants.yaml`.
   - **State account:** `gh variable get STATE_ACCOUNT -R TrislabCompany/tl-cloud-infrastructure`, for example `stplatformtfstate6884`.
4. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)):
   - lz, folder, stamp code, environment;
   - apps and caps, template version;
   - range, hostname and its access;
   - the GitHub Environment it will create in the app repository.
5. **Write**, on branch `stamp-<lz>-<folder>`.
   - **`stamps/<lz>/<folder>/stamp.yaml`**, in the style of the existing stamps:

     ```yaml
     # stamps/<lz>/<folder>/stamp.yaml
     template: aca-app
     version: <vX.Y.Z>
     lz: <lz>
     product: <product>
     environment: <environment>
     tenancy: dedicated
     network:
       subnet_cidr: <the /27>
     apps:
       - name: web
         repo: <repo>
         profile: Consumption
         ingress: external
         port: 8080
         caps: { cpu: 0.5, memory: 1Gi, max_replicas: 2 }
     ```

   - **`main.tf`**, from the generator at the pinned release:

     ```powershell
     git -C ../tl-platform fetch --tags; git -C ../tl-platform switch --detach "aca-app/<vX.Y.Z>"; pwsh ../tl-platform/stamps/aca-app/generate.ps1 -Stamp stamps/<lz>/<folder> -StateAccount <state account>; git -C ../tl-platform switch -
     ```

     Never edit `main.tf` by hand.
   - **`.terraform.lock.hcl`:**
     - Copy it from another stamp that pins the same `aca-app` version.
     - If there is none: `tofu -chdir=stamps/<lz>/<folder> init -backend=false`, then `tofu -chdir=stamps/<lz>/<folder> providers lock -platform=linux_amd64`, then delete `stamps/<lz>/<folder>/.terraform`.
     - The folder may hold only `stamp.yaml`, `main.tf` and `.terraform.lock.hcl`: `stamp-check` fails on anything else.
   - **`catalog/ipam.yaml`:** under the landing zone's entry, add `stamps:` if it is missing, then `<folder>: <the /27>`.
   - **`catalog/tenants.yaml`:** append under `tenants` (one tenant on a dedicated stamp):

     ```yaml
       - name: <product>
         customer: trislab                     # or the customer's slug
         stamp: <lz>/<folder>
         hostnames:
           - { fqdn: <default hostname>, app: <first external app> }
     ```

     Leave out `hostnames` when no app is `external`.
6. **Check** ([shared step 4](../_shared/pr.md#4-check)): `tofu fmt -check -recursive`, `check-catalog.py`, and that `main.tf`'s module `?ref=` is `aca-app/<vX.Y.Z>`.
7. **Open the PR** ([shared step 5](../_shared/pr.md#5-commit-push-open-the-pr)).
   - **Title:** "Create the stamp <stamp code> (<lz>/<folder>)".
   - **Roots:** `stamps/<lz>/<folder>` → `global/edge`, `global/github` → `stamps/<lz>/<folder>` again.
   - **Body:**
     - the hostname and its access;
     - the GitHub Environment it creates in `<repo>`;
     - for prod: "the Environment gets required reviewers; deploys reach it only by promotion".
8. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)). Then say what the app team does next: deploy (`release deploy` for `dev`, a tag for the release tier, or a promotion for `prod`) and check the hostname.

## Access

Hostnames of stamps in a sandbox landing zone are always behind Cloudflare Access (Entra sign-in: `grp-devops`, and `grp-sandbox-trislab` or `grp-cust-<code>-admins`). Prod hostnames are public, and only the domain's real hostname should be.

A `protected` prod hostname is written as `{ fqdn: …, app: …, access: protected }`. **This field takes effect only once the change that adds it is merged**, through `policy/catalog.rego` (which today allows only `fqdn` and `app`) and through `global/edge/records.tf` and `zero-trust.tf`. Check before writing:

```powershell
git grep -n "access" origin/main -- policy/catalog.rego global/edge/zero-trust.tf
```

If neither knows the field:
- **Don't write it:** the catalog rules would fail the PR.
- **Tell the user:** the hostname will be **public** until that change is merged and the field is added.
- **Ask** whether to go on or wait.
