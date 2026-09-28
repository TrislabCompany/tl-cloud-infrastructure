# ADR 0003: Customers and products get a short code

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Many resource names include the customer's or product's name, so you can see at a glance who a resource belongs to. But some cloud names are very short: a Key Vault name can have at most 24 characters. A name built from full words, like `kv-customer-okna-capris-sandbox`, has 31 and is rejected.

It's like an airline luggage tag. There is only room for three letters, so London Heathrow becomes `LHR`. Everyone learns the codes, and the tags stay short.

## The decision

- The word `customer` is always shortened to `cust`, and a graduated product uses `prdt`.
- Every customer and every product gets a unique **2–3 letter code**, e.g. `okna-capris` → `oc`, `construction` → `con`.
- The codes are listed in one register in [`03-naming-conventions.md`](../03-naming-conventions.md) section 4. A code is never reused.

## What this means in practice

- Names fit the cloud's limits: `kv-cust-oc-sandbox-4821` has 23 characters.
- Full names still appear wherever length doesn't matter: cost reports, tags, the tenant catalog and the repository folders. Reports remain readable.
- Onboarding a new customer includes picking their code and adding it to the register.

## Options we did not choose

| Option | Why not |
|---|---|
| Full names everywhere | Fails for many real customer names on Key Vaults, storage accounts and Google project IDs |
| Shorten each name case by case | Leads to inconsistent names for the same customer across resources |
| Random or numeric IDs | Short, but nobody can tell whose resource it is |

## Technical details

Codes are capped at 3 characters so the longest Key Vault pattern, `kv-prdt-<code>-sandbox-<nnnn>`, stays within 24. Register and rules: [`03-naming-conventions.md`](../03-naming-conventions.md) section 4.
