# ADR 0026: Vendor credentials reach a stamp through its landing zone's GitHub Environment

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Some of what a stamp needs is made outside Azure: its Neon Postgres project, its Upstash Redis database, and the credential to pull private images from GHCR. These are created by the platform team's identity (`spn-global-apply` for Neon and Upstash), but the stamp's apps read their secrets from the landing zone's Key Vault, which only the stamp's own deploy identity can write. It's like a supplier who delivers the keys to a building's front desk: the supplier must not be allowed into every tenant's office, and the tenant must still get the keys.

Letting the platform identity write into every landing zone's Key Vault would also let it read every owner's secrets, which breaks N4. Letting each stamp hold full vendor accounts would let one stamp change another stamp's database.

Example: `oc-con-prod` needs `DATABASE_URL` for its Neon project `oc-con-prod`, `REDIS_URL` for its Upstash database `oc-con-prod`, and a GHCR pull credential for `ghcr.io/<org>/construction-web`. All three must end up in `kv-cust-oc-prod-<nnnn>` as `oc-con-prod-*` secrets.

## The decision

The landing zone's GitHub Environment `lz-<lz>` is the hand-over point. GitHub Environment secrets can be written but never read back through the API, so a writer can hand a value over without being able to read what is there.

| Credential | Written to `lz-<lz>` by | What the stamp does with it |
|---|---|---|
| A Neon **project-scoped API key** for the stamp's project | `global/external-providers` | Uses it with the Neon provider to create its own database and role, and writes the connection URL into `<stamp>-postgres-url` |
| The Upstash database's **connection URL** (Upstash has no key narrower than the whole team) | `global/external-providers` | Copies it into `<stamp>-redis-url` |
| The **GHCR pull token** | The `landing-zone` module, once per landing zone | Copies it into `<stamp>-ghcr-pull`, which its apps use as their registry password |

Nobody but the stamp's own deploy identity writes the landing zone's Key Vault ([ADR 0024](./0024-deploy-identity-grants-stamp-roles.md)).

## What this means in practice

- `spn-global-apply` and `spn-landingzones-apply` never get rights on any landing zone's Key Vault. They can put a value into a landing zone's Environment but can't read any secret there.
- A stamp's Neon key reaches only its own Neon project. Its Upstash URL reaches only its own database. A stamp can't reach another stamp's data.
- Adding `data.postgres.provider: neon` or `data.cache.provider: upstash` to a stamp needs a `global` apply before the stamp can finish: the `global` PR creates the project or database and writes the credential. The stamp skips a data block whose credential isn't there yet, and completes on its next apply.
- Rotating a credential means the writer writes a new value and raises its version. The stamps concerned pick it up on their next apply (specified in `08-pipeline.md`).
- The GHCR pull token belongs to a machine user, because GHCR accepts only classic tokens tied to a user. It is rotated by hand, like the GitHub App keys.

## Options we did not choose

| Option | Why not |
|---|---|
| `spn-global-apply` writes into every landing zone's Key Vault | It would need Key Vault Secrets Officer on every vault, and so could read every owner's secrets (N4) |
| The `landing-zone` module writes the GHCR token into the Key Vault | Same problem: `spn-landingzones-apply` would then read every owner's secrets. It writes the token into the Environment instead, which it already manages ([ADR 0019](./0019-github-app-for-landing-zone-environments.md)) |
| Each stamp holds a full Neon or Upstash account key | One stamp could change or delete another stamp's database, including across owners |
| `global` creates the Neon database and role too, and hands over the URL | Works, and is the fallback if a project-scoped key can't be created by code. With the key, the stamp owns its role and can rotate its password itself |
| Engineers copy the values into the Key Vault by hand | A manual step for every stamp, against N11 |

## Technical details

- **Names in `lz-<lz>`.** GitHub secret names allow only letters, digits and underscores, so `<STAMP>` is the stamp code in capitals with `_` for `-` ([03 section 8](../03-naming-conventions.md#8-github-names)):

  | Secret | Variable next to it | Written by |
  |---|---|---|
  | `NEON_KEY_<STAMP>`, e.g. `NEON_KEY_OC_CON_PROD` | `NEON_KEY_<STAMP>_VERSION` | `global/external-providers/neon.tf` |
  | `REDIS_URL_<STAMP>` | `REDIS_URL_<STAMP>_VERSION` | `global/external-providers/upstash.tf` |
  | `GHCR_PULL_TOKEN` | `GHCR_PULL_TOKEN_VERSION` | The `landing-zone` module, from the `landingzones` Environment secret of the same name |

- **Versions.** Each `_VERSION` variable is an integer the writer raises when it writes a new value. The stamp passes it to `value_wo_version` on the Key Vault secret, so a new value is written exactly when the version changes.
- **Into OpenTofu.** The apply job passes the stamp's own secrets as input variables declared `ephemeral = true`, so they are never stored in the saved plan or the state. PR plan jobs don't run in `lz-<lz>` and get no secrets. **To check in the pilot:** that a plan with these variables unset and an apply of the saved plan with them set works as expected. If it doesn't, plan jobs get a placeholder value.
- **Neon role password.** The Neon provider stores the role's password in the stamp's state. The state is readable only by that landing zone's deploy identity (specified in `08-pipeline.md`), which can already read the Key Vault secret holding the same value.
- **To check in the pilot:** that the Neon provider can create a project-scoped API key. If it can't, `global` creates the database and role and hands over the URL instead, as for Upstash.
- **GitHub access for `global`.** `spn-global-apply` writes Environment secrets and variables through a new GitHub App, `tl-global-apply`, whose private key is a secret of the `global` Environment. **To check in the pilot:** which App permissions GitHub requires for Environment secrets and variables, and whether they also allow changing an Environment's reviewers. If they do, a changed reviewer list still shows in the nightly drift plan of `landing-zones/_root`, which owns it.
- **GCP:** the same hand-over works for Secret Manager, with the stamp's deploy service account writing the secret versions.
- **Spec changes:** [02 section 6](../02-architecture.md#6-identity-and-access) (the `spn-global-apply` row and the secrets table), [03 sections 7.4 and 8](../03-naming-conventions.md#8-github-names), [04](../04-repository-structure.md) (`global/external-providers`), [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 8, and [06 sections 6.3, 6.4 and 6.7](../06-stamp-templates.md#67-data-building-blocks).
