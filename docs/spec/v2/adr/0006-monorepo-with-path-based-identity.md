# ADR 0006: One infrastructure repository; the folder decides which identity applies it

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

All infrastructure is written as code and applied by automation. The automation logs into the cloud with an identity, a kind of key card. If one key card could change everything (the platform and every customer), a single mistake or leak could damage everything at once.

One way to avoid that is a separate repository per layer, each with its own key card. For a small team, that means many places to maintain and many cross-repository changes.

## The decision

We keep **one infrastructure repository**, and **the folder a change is in decides which key card the automation gets**. A change under `platform/` can only use the platform identity. A change under `stamps/cust-oc-prod/` can only use that landing zone's identity. The cloud itself enforces this: each identity trusts only its own GitHub Environment.

## What this means in practice

- One place to look, one review process, one pipeline.
- A change to one customer's environment physically cannot touch another customer or the platform.
- Code owners per folder decide who has to review what.

## Options we did not choose

| Option | Why not |
|---|---|
| One repository per layer | More overhead for a small team, and cross-layer changes need several coordinated PRs |
| One repository, one powerful identity | A single mistake or leak could affect every customer |

## Technical details

Identity table and repository layout: [`02-architecture.md`](../02-architecture.md) sections 6–7.
