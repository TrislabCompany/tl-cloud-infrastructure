# ADR 0008: GCP follows the same model, built only when the first GCP customer arrives

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Azure is our main cloud. Some customers may require Google Cloud (GCP). Building and running the full GCP setup now would cost time and money before any customer needs it. But if we designed GCP separately later, we'd end up with two different ways of working.

## The decision

The design covers GCP with the **same shape** as Azure (folders instead of management groups, projects instead of subscriptions, the same landing zones and stamps). It is **built only when the first GCP-only customer signs**.

## What this means in practice

- No GCP running costs or maintenance until there is a paying reason.
- When the first GCP customer arrives, we fill in a known design instead of inventing a new one.
- A GCP-only customer never depends on anything in Azure (F5).

## Options we did not choose

| Option | Why not |
|---|---|
| Build GCP now, in parallel | Cost and effort with no customer to justify it |
| Design GCP only when needed | Risks a second, inconsistent model |

## Technical details

GCP hierarchy: [`02-architecture.md`](../02-architecture.md) section 2; `cloudrun-app` template: section 5.
