# ADR 0001: Names don't carry the company token

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Every cloud resource needs a name. Until now, names started with `tl` (short for Trislab), for example `spn-tl-global-apply`.

Think of labelling the folders in your own office filing cabinet "Trislab — Invoices", "Trislab — Contracts". Everything in the cabinet already belongs to Trislab, so the word adds nothing. It only makes every label longer. In the cloud, labels have strict length limits, so every wasted character counts.

## The decision

No resource name contains `tl` or `trislab`. `spn-tl-global-apply` becomes `spn-global-apply`.

## What this means in practice

- Names are shorter and easier to read.
- The characters saved go to information that matters: who owns the resource and which environment it belongs to.
- GitHub repository names (such as `tl-cloud-infrastructure`) are not cloud resources and stay unchanged.
- Some names must be unique among *all* cloud customers worldwide. For those, uniqueness comes from a number suffix instead ([ADR 0002](./0002-globally-unique-names-get-a-suffix.md)).

## Options we did not choose

| Option | Why not |
|---|---|
| Keep `tl` everywhere | It adds no information inside Trislab's own tenant and uses up scarce characters |
| Keep `tl` only on globally unique names | Other companies can still take those names, and it doesn't solve name reuse after deletion (see ADR 0002) |

## Technical details

Grammar and examples: [`03-naming-conventions.md`](../03-naming-conventions.md) sections 1–2.
