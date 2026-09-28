# ADR 0032: State access is split per layer and per landing zone, and plans don't lock

> Part of [spec v2](../README.md).

- **Status:** proposed
- **Date:** 2026-09-28

## The problem

OpenTofu keeps a state file for each root: its record of what it built. All state files live in one storage account, `stplatformtfstate<nnnn>`, in four containers, one per layer. Think of a filing cabinet with four drawers, where each drawer has folders. Each identity needs its own folders and nothing else. A landing zone's deploy identity in particular must reach its own stamps' states and no other landing zone's, because a state file can hold details of what it built.

Two facts make this harder. First, a plan reads state but also takes a lock on it, and taking a lock counts as writing. So a "read-only" plan identity would need write access. Second, every landing zone's stamps share one drawer, `tfstate-stamps`.

Example: `spn-lz-cust-asg-prod-neu-deploy` must write `tfstate-stamps/cust-asg-prod-neu/construction.tfstate`, but must not read `tfstate-stamps/cust-oc-prod-neu/construction.tfstate`.

## The decision

1. **Per layer:** each layer's plan identity gets Storage Blob Data Reader and its apply identity Storage Blob Data Contributor, on its own container only.
2. **Per landing zone:** `spn-lz-<lz>-plan` and `spn-lz-<lz>-deploy` get the same two roles on `tfstate-stamps`, with a condition that limits them to blobs whose path starts with `<lz>/`. The `landing-zone` module grants them.
3. **Plans don't lock.** Plans run with `-lock=false`. Applies always lock, and refuse a saved plan whose state has changed.

## What this means in practice

- No identity can read or change another layer's state, and no landing zone can read another landing zone's stamps.
- Plan identities stay truly read-only.
- A plan made while an apply is running may be out of date. It can't do harm: applying it is refused, and the pipeline plans again ([`08-pipeline.md`](../08-pipeline.md) section 4).
- `spn-landingzones-apply` gets one more right: it may assign those two roles on the `tfstate-stamps` container, and only those two.

## Options we did not choose

| Option | Why not |
|---|---|
| Plan identities get write access so plans can lock | A plan identity is available to every PR job, so any PR could overwrite state |
| One storage account or container per landing zone | Many more storage accounts with global names and suffixes, and a new one to create per landing zone. The path condition gives the same isolation |
| All landing zone identities read all of `tfstate-stamps` | One customer's pipeline could read another customer's stamp states (N4) |

## Technical details

- **Condition** on the role assignment, version 2.0:
  `@Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path] StringStartsWith '<lz>/'`. The same condition is needed for list operations, so that `tofu` can check the key exists.
- **The grant right.** `platform/azure/state` gives `spn-landingzones-apply` Role Based Access Control Administrator on the `tfstate-stamps` container, with a condition that allows assigning only Storage Blob Data Reader and Storage Blob Data Contributor, to service principals.
- **Seed.** The seed gives `spn-platform-plan` and `spn-platform-apply` their rights on `tfstate-platform` ([`09-bootstrap.md`](../09-bootstrap.md)). `platform/azure/state` adopts them.
- **GCP.** The same on the GCS bucket, with IAM conditions on `resource.name` starting with the prefix.
- **Spec changes on acceptance:** add the state rights to the identity table in [02 section 6](../02-architecture.md#6-identity-and-access) and to [05 section 4](../05-landing-zones.md#4-what-one-apply-creates) step 8.
