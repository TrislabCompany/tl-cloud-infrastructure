---
name: hostname-delete
description: Delete a custom hostname from a stamp in tl-cloud-infrastructure — remove it from the tenant's hostnames in catalog/domains.yaml and, when it should point elsewhere again, add its outside record to global/edge/records/<zone>/ — as one PR opened with the user's own gh credentials; the stamp unbinds it and global/edge deletes its DNS records. Use when the user asks to delete, remove, detach, unbind or deprovision a hostname or domain from a stamp, or to point a domain back to another host.
metadata:
  owner: infrastructure
---

# hostname-delete

One PR. The stamp unbinds the name, and `global/edge` deletes its CNAME, `asuid` TXT and, in a sandbox landing zone, its Access application. The two can apply in either order.

A stamp's default hostname (`<env>-<product>….trislab.com`) is not deleted this way: it goes with the stamp ([`stamp-destroy`](../stamp-destroy/SKILL.md)). To move a hostname to another stamp, use [`hostname-create`](../hostname-create/SKILL.md) on the new stamp and remove it from the old tenant in the same PR. Then `global` applies first, the new stamp binds, and the old stamp unbinds.

Follow [the shared steps](../_shared/pr.md). The rules are in [AGENTS.md](../../../AGENTS.md).

## Inputs

| Input | Required |
| --- | --- |
| `fqdn` | yes |
| `point to` | no: a record to write instead, such as `A 212.44.101.122` with `proxied: true`, when the name goes back to an outside host |

## Steps

1. **Preflight** ([shared step 1](../_shared/pr.md#1-preflight)).
2. **Find it:** the tenant and stamp whose `hostnames` hold `fqdn`.
   - If it is the stamp's default hostname, stop and point to `stamp-destroy`.
   - If it is a domain root that `redirects` point to (for example `www.trislab.com → trislab.com`), say that the redirect then leads nowhere unless `point to` is given.
3. **Show and ask** ([shared step 2](../_shared/pr.md#2-show-then-ask)): the name stops answering at the apply, unless `point to` is given.
4. **Write**, on branch `delete-hostname-<fqdn with dots as dashes>`.
   - **`catalog/domains.yaml`:** delete the hostname's line. Keep the tenant and its other hostnames.
   - **With `point to`:** add a line to `global/edge/records/<zone>/<zone>.yaml`, in the file's style:

     ```yaml
     apex: { name: <fqdn>, type: A, content: <ip>, proxied: true }
     ```

     Use a key the file doesn't use yet, and add a comment that says where it points and why.
5. **Check and open the PR** ([shared steps 4 and 5](../_shared/pr.md#4-check)).
   - **Title:** "Delete <fqdn> from <stamp code>", or "Point <fqdn> back to <target>".
   - **Roots:** `stamps/<lz>/<folder>` and `global/edge`.
6. **Stop** ([shared step 6](../_shared/pr.md#6-stop-at-the-pr)).
