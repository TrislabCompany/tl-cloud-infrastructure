# ADR 0033: GCP state storage is built before the first GCP customer

> Part of [spec v2](../README.md).

- **Status:** proposed
- **Date:** 2026-09-28

## The problem

N10 in [01](../01-requirements.md) says state is backed up across clouds: every night, Azure state is copied to Google Cloud Storage. It's like keeping a copy of the house keys at a friend's place in another town. [ADR 0008](./0008-gcp-built-on-first-customer.md) says the GCP side of the platform is built only when the first GCP customer arrives. Until then there would be no bucket to copy into, so the Azure state would have no copy in another cloud.

Example: if `stplatformtfstate<nnnn>` were deleted by mistake, soft delete brings it back for a while. If the Azure subscription itself were lost, only a copy outside Azure helps.

## The decision

Only the GCP state storage is built early, with the platform: `prj-platform-<nnnn>` with the bucket `gcs-platform-tfstate-<nnnn>`, and a nightly Storage Transfer Service job that copies the Azure state into it. The rest of GCP (folders, organization policies, hub, landing zones) still waits for the first GCP customer.

## What this means in practice

- The Azure state has a nightly copy in GCP from the first platform apply on.
- GCP costs almost nothing until the first customer: one project and a small bucket.
- The GCP seed shrinks to the organization admin creating the project and the bucket, in the same seed as Azure ([`09-bootstrap.md`](../09-bootstrap.md)).

## Options we did not choose

| Option | Why not |
|---|---|
| No copy until the first GCP customer | N10 isn't met, maybe for a long time |
| Copy to a second Azure storage account in `italynorth` | Protects against a lost account or region, not against losing the subscription or the Azure tenant. N10 asks for another cloud |
| Build all of GCP now | Against ADR 0008: cost and upkeep before any customer needs it |

## Technical details

- **Roots:** only two GCP roots are built now. `platform/gcp/identity` adopts the seed's pool `wif-github` and the service accounts `sa-platform-plan` and `sa-platform-apply`. `platform/gcp/state` holds the bucket and the copy job. `governance`, `connectivity` and `management` wait for the first GCP customer.
- **Copy job:** a Storage Transfer Service job in `platform/gcp/state` that pulls the four Azure containers into the bucket every night, one prefix per container. It signs in to Azure as the app registration `spn-platform-statecopy`, which has Storage Blob Data Reader on the four containers and a federated credential that trusts only the transfer service's Google identity. So the copy needs no stored secret. The bucket has versioning and keeps old versions for 30 days.
- **To check when building it:** that the transfer service's federated sign-in to Azure works for `europe-west8`. If it doesn't, the copy runs as a nightly workflow with `azcopy` and a short-lived token instead.
- **Who can read the copy:** only the platform admins and `sa-platform-apply`. The transfer service can only write. The copy holds every layer's state.
- **Spec changes on acceptance:** [04](../04-repository-structure.md) notes that `platform/gcp/state` is built with the platform, not with the first GCP customer, and holds the copy job; `spn-platform-statecopy` is added to [03 section 7.2](../03-naming-conventions.md#72-l1-platform-landing-zone).
