# ADR 0012: The tenant catalog stays a YAML file in the repository

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

The tenant catalog is our address book. For every tenant it records which stamp serves it, in which landing zone and region, and under which hostnames. DNS and routing are generated from it, so one wrong line can send a customer's traffic to the wrong place.

Once the developer portal offers self-service, people will add tenants from the portal instead of editing files. We had to decide where the address book lives then: in the repository as a file, or in the portal's own database.

For example, when a new tenant `cust-oc` gets the hostname `app.okna-capris.si`, that change should be reviewed and recorded in the same way as any other infrastructure change.

## The decision

The catalog stays a **YAML file in `tl-cloud-infrastructure`** (`catalog/tenants.yaml`, with the IP plan in `catalog/ipam.yaml`), also after self-service is live. The portal changes it only by **opening a pull request**.

## What this means in practice

- There is one source of truth, and it is in git.
- Every change is reviewed in a PR, and the history shows who changed what and when.
- The portal is a convenient way to write the PR, not a second place where data is kept.
- Restoring an old state of the catalog is a git revert.

## Options we did not choose

| Option | Why not |
|---|---|
| Portal database as the source of truth, synced into the repository | Two copies that can drift apart, and portal changes would skip PR review |

## Technical details

Principle 5 and the portal row in [`02-architecture.md`](../02-architecture.md) (sections 1 and 7). The catalog and IP plan schema will be specified in `07-catalog-and-ipam.md` (see [`TODO.md`](../TODO.md)).
