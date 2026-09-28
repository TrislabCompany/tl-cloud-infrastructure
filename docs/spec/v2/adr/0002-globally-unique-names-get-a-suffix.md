# ADR 0002: Names that must be globally unique get a 4-digit suffix

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Most resource names only need to be unique inside Trislab's own cloud account, like room names inside our own building. A few kinds of resource are different. Their name becomes a **public web address** that every Azure or Google Cloud customer in the world shares. A Key Vault (a safe for passwords and keys) called `kv-platform` gets the address `kv-platform.vault.azure.net`. Just like a website domain, only one company in the world can have it.

We checked this on 2026-09-25. These names are **already taken by other companies**: `kv-platform`, `kv-platform-prod`, `kv-management`, `kv-shared`, `kv-hub`, `kv-sandbox`, `kv-dev`, `kv-test` (Key Vaults), `stplatform`, `sttfstate` (storage accounts), and `tfstate`, `tfstate-platform` (Google storage buckets). If our design had used any of these names, the first deployment would have failed.

There is a second, less obvious problem: **we can block ourselves**. When a Key Vault is deleted, Azure keeps it in a "recycle bin" for up to 90 days, and its name stays reserved all that time. Google never releases a deleted project's name. So if we move a landing zone to another region, or remove a customer's environment and create it again, the new vault asks for the same name and is refused until the old one is gone.

## The decision

Every resource whose name must be globally unique gets a **4-digit number at the end**, for example `kv-cust-oc-sandbox-4821`. The number is generated automatically once and remembered. It changes automatically when the resource is recreated or moved to another region.

## What this means in practice

- Deployments don't fail because another company took a name first.
- Moving a region or recreating an environment works straight away, with no wait for the recycle bin to empty.
- Nobody picks or types the number. The automation creates it and shows it where needed.
- Only a few resource types are affected: Key Vaults, storage accounts, PostgreSQL servers, Function apps, Google project IDs and Google storage buckets. All other names stay suffix-free.

## Options we did not choose

| Option | Why not |
|---|---|
| Readable names only, checked by hand before use | Someone can take the name between our check and our deployment, and it doesn't fix recreating a deleted resource |
| Put `tl` back only on these names | Less likely to be taken, but no guarantee, and it still fails when recreating a deleted vault |
| Company token plus suffix | Uses more of the 24-character Key Vault limit for no extra benefit |

## Technical details

- Evidence: public DNS resolution of `<name>.vault.azure.net` and `<name>.blob.core.windows.net`, and HTTP 403 from `storage.googleapis.com/<bucket>` (bucket exists, not ours), checked 2026-09-25.
- Key Vault soft delete is always on (7–90 days retention). With purge protection, which regulated landing zones require, the name can't be freed early.
- A Key Vault's location can't be changed in place. A region switch (N6) destroys and recreates it.
- The suffix is a `random_integer` (1000–9999) per state with `keepers` on region. Full rules and length budgets: [`03-naming-conventions.md`](../03-naming-conventions.md) section 6.
