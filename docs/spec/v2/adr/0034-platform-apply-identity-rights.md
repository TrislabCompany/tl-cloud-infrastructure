# ADR 0034: What the platform apply identity may do, and which rights stay manual

> Part of [spec v2](../README.md).

- **Status:** proposed
- **Date:** 2026-09-28

## The problem

`spn-platform-apply` builds the platform layer: the management groups, the policies, and the pipeline identities of every other layer. [02 section 6](../02-architecture.md#6-identity-and-access) gives it Owner on `mg-platform` and Resource Policy Contributor on `mg-root`. That isn't enough for what `platform/azure/identity` and `platform/azure/governance` must do:
- create `mg-landingzones` and its children below `mg-root`;
- create the app registrations of `spn-global-*` and `spn-landingzones-*` in Entra ID;
- give those identities their roles on `mg-root`, `mg-landingzones` and `mg-decommissioned`.

It's like a building manager who holds the keys to the basement but is also asked to cut keys for the other tenants. Some keys can't be cut from the basement key at all.

Some rights can't be granted safely by a pipeline. To let `spn-platform-apply` grant Microsoft Graph permissions to other identities, it would need a right that allows it to make any application a Global Administrator.

Example: `spn-landingzones-apply` creates `spn-lz-<lz>-plan` and `spn-lz-<lz>-deploy` for every landing zone, so it needs the Graph permission to create app registrations. Someone has to grant it that permission once.

## The decision

`spn-platform-apply` gets these rights, and nothing else:

| Scope | Right | Why |
|---|---|---|
| `mg-platform` | Owner | Everything inside the platform subscriptions |
| `mg-root` | Management Group Contributor | Create and move the management groups below `mg-root` |
| `mg-root` | Resource Policy Contributor | Policy definitions and assignments |
| `mg-root` | User Access Administrator | Give the other layers' identities their roles, including the conditional User Access Administrator of `spn-landingzones-apply` |
| Microsoft Graph | `Application.ReadWrite.OwnedBy` | Create the pipeline app registrations, and manage only the ones it owns |
| Microsoft Graph | `Group.Create` | Create the Entra groups in `platform/azure/identity` (`grp-devops`, `grp-platform-admins`, `grp-regulated-admins`, and each `grp-cust-<code>-admins`), and manage the groups it created |

Microsoft Graph permissions are **granted by hand**, once each, by a Privileged Role Administrator: to `spn-platform-apply` in the seed, and `Application.ReadWrite.OwnedBy` to `spn-landingzones-apply` right after `platform/azure/identity` creates it, next to its billing grant ([`09-bootstrap.md`](../09-bootstrap.md)).

## What this means in practice

- The `platform` Environment is the most powerful door in the pipeline. Only `platform-admins` can open it, and once iTop runs, only with an approved Change Request ([ADR 0029](./0029-environment-approval-gate-until-itop.md), [ADR 0031](./0031-environment-reviewers-and-layer-environments.md)).
- No pipeline identity can grant Graph permissions. Two manual grants in the seed replace that.
- A customer's admin group is created in `platform/azure/identity` in the onboarding PR, next to the customer's `lz.yaml` files. It needs a `platform` apply.

## Options we did not choose

| Option | Why not |
|---|---|
| Keep the rights in 02 section 6 | The platform roots can't be applied: they can't create the landing zone management groups or the other pipeline identities |
| Give `spn-platform-apply` `AppRoleAssignment.ReadWrite.All` so it grants Graph permissions itself | That permission lets it grant any permission to any app, including itself, which makes it equal to a Global Administrator |
| Create all pipeline identities by hand in the seed | Many more manual steps, and identities outside code drift without anyone noticing (N11) |
| The `landing-zone` module creates each customer's admin group | `spn-landingzones-apply` would need `Group.Create` too, and groups would be spread over two layers |

## Technical details

- **Seed ownership.** The seed makes `spn-platform-apply` an owner of both seed app registrations, so `platform/azure/identity` can adopt them with `Application.ReadWrite.OwnedBy`.
- **PIM.** Making Trislab groups PIM-eligible for Azure roles uses Azure Resource Manager, which the `mg-root` User Access Administrator covers. No Graph role management permission is needed.
- **Spec changes on acceptance:** the `spn-platform-apply` row in [02 section 6](../02-architecture.md#6-identity-and-access), the manual steps in [02 section 12](../02-architecture.md#12-bootstrap-manual-seed), `groups.tf` in [04](../04-repository-structure.md), and step 1 of "Onboard a new customer" in [02 section 11](../02-architecture.md#11-key-scenarios).
