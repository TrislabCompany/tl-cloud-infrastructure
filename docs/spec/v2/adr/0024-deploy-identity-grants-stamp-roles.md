# ADR 0024: A landing zone's deploy identity may grant the stamps' own roles and write their secrets

> Part of [spec v2](../README.md).

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

Every stamp hands out two keys when it is built. Its apps get a key to their own secrets in the landing zone's Key Vault, and the app repository's pipeline gets a key to update those apps. It's like a building manager who can furnish rooms but isn't allowed to cut keys: the rooms are ready, but nobody can get in.

Each landing zone's stamps are applied with `spn-lz-<lz>-deploy`, which is Contributor on the subscription. Contributor can create resources, but it can't create role assignments, and it can't write secrets into a Key Vault that uses RBAC. So no stamp template works as specified in [06](../06-stamp-templates.md).

Example: the stamp `oc-con-prod` needs to give `id-oc-con-prod-workload` read access to `oc-con-prod-session-key`, give `id-oc-con-prod-appdeploy` the right to update `ca-oc-con-prod-web`, and write `oc-con-prod-postgres-url` into `kv-cust-oc-prod-<nnnn>`. With Contributor alone, all three fail.

## The decision

The `landing-zone` module gives `spn-lz-<lz>-deploy` two more roles, next to Contributor:

| Role | Scope | Limit |
|---|---|---|
| Role Based Access Control Administrator | The landing zone's subscription | A condition allows only assigning and removing **Key Vault Secrets User** and the custom role **"Stamp app deploy"**, and only to service principals (managed identities are service principals) |
| Key Vault Secrets Officer | The landing zone's Key Vault | — |

"Stamp app deploy" is a custom role that can read and update container apps and their revisions, and nothing else. `platform/azure/governance` defines it.

The stamp's plan identity `spn-lz-<lz>-plan` also gets **Key Vault Reader** on the vault, which shows secrets' names and dates but never their values.

## What this means in practice

- A stamp can give its own apps access to its own secrets, and its app-deploy identity access to its own apps. It still can't give anyone Owner, Contributor or access to anything else.
- The deploy identity can read every secret in its landing zone's Key Vault. It already controls every stamp in that landing zone, so this doesn't widen what it can reach, and it still can't reach any other owner's vault (N4).
- Secret values are written as write-only values: they are never stored in a stamp's state, and a PR plan never reads them.
- Engineers who set secret values by hand (the declared secrets in [06 section 6.4](../06-stamp-templates.md#64-secrets)) get Key Vault Secrets Officer through the landing zone's `access` list, activated through PIM.
- The fixed set of roles that `spn-landingzones-apply` may assign grows by these roles.

## Options we did not choose

| Option | Why not |
|---|---|
| The `landing-zone` module creates each stamp's identities and role assignments | Every new stamp would need a PR in the `landingzones` layer first, and a stamp would no longer be one folder |
| User Access Administrator or Owner for the deploy identity | It could give any role to anyone, including Owner to a guest account |
| Key Vault access policies instead of RBAC | Access policies work on the whole vault, so every stamp could read every other stamp's secrets |
| A Key Vault per stamp | The vault still needs a role assignment for the workload identity, so the deploy identity needs the same right. It also adds a globally unique name and a CMK setup per stamp in regulated landing zones |
| The platform team creates the role assignments by hand | A manual step for every stamp, against N11 |

## Technical details

- **Condition on the RBAC Administrator assignment** (the "constrain roles and principal types" pattern):

  | Action | Allowed when |
  |---|---|
  | `Microsoft.Authorization/roleAssignments/write` | `@Request[...roleAssignments:RoleDefinitionId]` is Key Vault Secrets User or "Stamp app deploy", and `@Request[...roleAssignments:PrincipalType]` is `ServicePrincipal` |
  | `Microsoft.Authorization/roleAssignments/delete` | `@Resource[...roleAssignments:RoleDefinitionId]` is one of the same two roles |

- **"Stamp app deploy" actions:** `Microsoft.App/containerApps/read`, `Microsoft.App/containerApps/write`, `Microsoft.App/containerApps/revisions/*`, `Microsoft.App/managedEnvironments/read`, `Microsoft.App/managedEnvironments/join/action`. It has no `listSecrets` action and no `Microsoft.ManagedIdentity/userAssignedIdentities/assign/action`, so it can't read an app's secrets or attach another identity. Assignable scope: `mg-landingzones`.
- **Write-only secret values:** the template sets secrets with `value_wo` and `value_wo_version` on `azurerm_key_vault_secret`, so the provider needs only secret metadata when it refreshes. **To check in the pilot:** that a refresh works with Key Vault Reader only. If it doesn't, the plan identity needs Key Vault Secrets User on the vault, and this ADR is revisited.
- **To check in the pilot:** whether updating an app that already uses `id-<stamp>-workload` needs `assign/action` on that identity. If it does, the stamp also assigns Managed Identity Operator on its own workload identity to its app-deploy identity, and that role joins the condition.
- **Risk:** `spn-landingzones-apply` can assign RBAC Administrator, and Azure can't check the condition it attaches. A wrong condition is caught in plan review and by the nightly drift check, as with the peering role in [ADR 0018](./0018-hub-peering-custom-role.md).
- **GCP:** the same need exists for `sa-lz-<scope>-<envtype>-deploy`: granting `roles/secretmanager.secretAccessor` per secret and writing secret versions. The GCP roles and their limits are specified with `cloudrun-app`.
- **Spec changes on acceptance:**
  - [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 8: add the two roles for `spn-lz-<lz>-deploy` and Key Vault Reader for `spn-lz-<lz>-plan`.
  - [02 section 6](../02-architecture.md#6-identity-and-access): update the `spn-lz-<lz>-deploy`, `spn-lz-<lz>-plan` and `id-<stamp>-appdeploy` rows, and list the fixed set of landing zone roles on the `spn-landingzones-apply` row.
  - [04](../04-repository-structure.md): add the "Stamp app deploy" role definition to `platform/azure/governance`.
  - [06](../06-stamp-templates.md): drop "proposed" from sections 1 and 12.
