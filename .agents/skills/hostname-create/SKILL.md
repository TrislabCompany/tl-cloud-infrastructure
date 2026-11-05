---
name: hostname-create
description: Add a custom hostname (such as trislab.com or portal.example.com) to a stamp in tl-cloud-infrastructure — add it to the stamp's tenant in catalog/tenants.yaml, public or protected, and, when the name moves from an outside host, delete its old A/AAAA/CNAME record from global/edge/records/<zone>/ in the same PR while keeping mail and other records — as one PR opened with the user's own gh credentials. Use when the user asks to add, create, attach, bind, point, move, switch or cut over a domain, apex or hostname to a stamp, or go live on a domain.
metadata:
  owner: infrastructure
---

# hostname-create

One PR, applied in two passes:
1. **`global/edge`** writes the proxied CNAME (flattened at a zone's apex) and the `asuid` TXT, and lists the name in the landing zone's `EDGE_HOSTNAMES`.
2. **The stamp** binds the name with the zone's origin certificate.

When the name pointed somewhere else, its old record goes in the same PR. From the `global` apply on, the name reaches the stamp.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required | Rule |
| --- | --- | --- |
| `fqdn` | yes | Lowercase. The domain root or one label below it. Never two (`www.portal.example.com`), so the free certificate covers it |
| `stamp` | yes | `<lz>/<folder>` or its code. It has a tenant in `catalog/tenants.yaml` |
| `app` | no | An app of the stamp with `ingress: external`. Default: the first one |
| `access` | no | `public` (default in prod) or `protected`. Always `protected` in a sandbox landing zone, where the field is left out. See [stamp-create, Access](../stamp-create/SKILL.md#access) |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)).
2. **Preconditions.** Stop with the reason when one fails.
   - **The domain:** the longest `domains[].name` in `catalog/tenants.yaml` that `fqdn` ends with.
     - If none, the domain isn't on Cloudflare yet. That is a separate PR first: add the domain to `domains`, and its existing records (mail and others, from the current DNS host's export, not proxied) to `global/edge/records/<domain>/<domain>.yaml`. Then the domain's owner lists Cloudflare's nameservers at the registrar. Offer to open that PR, and stop here.
     - **Delegation:** `Resolve-DnsName <domain> -Type NS` lists Cloudflare's nameservers (`*.ns.cloudflare.com`). The plan fails otherwise.
   - **Ownership:** a customer's domain serves only that customer's tenants. A Trislab domain serves any tenant.
   - **Not already in use:**
     - `fqdn` is in no tenant's `hostnames`;
     - it is not a `redirects[].from` (a redirect source can't also be a hostname);
     - it is not a derived hostname of any stamp.
   - **The stamp:** it exists on `main`, is applied, and the app has `ingress: external`.
3. **Find the old record:** look in `global/edge/records/<zone>/*.yaml` for an entry with `name: <fqdn>` and `type: A`, `AAAA` or `CNAME`. Example: `apex: { name: trislab.com, type: A, content: 212.44.101.122, proxied: true }`.
   - **That entry goes in this PR:** a name can't be both a record and a stamp hostname.
   - **Records on the same name with other types stay:** `MX`, `TXT` (SPF, verification, DMARC), `CAA`.
   - **Records that point *to* the name stay too,** such as `www: CNAME trislab.com`, and so do redirects such as `www.trislab.com → trislab.com`.
4. **The cut-over,** when an old record exists. Show this to the user, and put it in the PR body:
   - **The switch:** the name leaves the old host at the `global/edge` apply. The certificate binding comes with the stamp's second pass a few minutes later, and Cloudflare serves an error in between. Apply at a quiet hour, with both approvers ready.
   - **Unconfirmed:** whether Cloudflare accepts the new CNAME in the same apply that deletes the A record, and whether Azure validates an apex behind a flattened, proxied CNAME (ADR 0027 lists both as pilot checks). If the plan or the bind fails, the rollback is to revert the PR, which restores the old record.
   - **Check before:** the stamp serves the right version on its default hostname.
5. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)): the hostname, the stamp and app, its access, the record that is deleted and the records that stay.
6. **Write**, on branch `hostname-<fqdn with dots as dashes>`.
   - **`catalog/tenants.yaml`:** append `- { fqdn: <fqdn>, app: <app> }` (with `, access: protected` for a protected prod hostname; never `access: public` in a sandbox) to the stamp's tenant's `hostnames`.
   - **`global/edge/records/<zone>/<file>.yaml`:**
     - delete the old record's line;
     - fix the comment above it so it still tells the truth, for example "The corporate site runs on the platform (stamp `shr-web-prod`); its records come from catalog/tenants.yaml."
7. **Check and open the PR** ([shared steps 4 and 5](../_shared/pr.md#4-check)).
   - **Title:** "Add <fqdn> to <stamp code>". For a move: "Move <fqdn> from <old content> to <stamp code>".
   - **Roots:** `global/edge` → `stamps/<lz>/<folder>`.
   - **Body:**
     - the cut-over notes;
     - how to verify: `curl -sI https://<fqdn>` (public: 200, served by the stamp; protected: a redirect to `trislab.cloudflareaccess.com`);
     - for a domain root: `Resolve-DnsName <fqdn> -Type MX` is unchanged.
8. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)).
