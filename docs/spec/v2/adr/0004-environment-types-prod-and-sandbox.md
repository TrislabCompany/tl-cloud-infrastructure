# ADR 0004: Environments are either production or sandbox

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Software runs in several copies, called environments. **Production** is the one real customers use. The others (dev, test, demo, previews) are places to build and try things safely. The design called the second group "non-production" or "nonprod", while the product requirements already called it "sandbox". Two words for one idea cause confusion in names, tags and conversations.

It's like a restaurant with the dining room (production) and the test kitchen (sandbox). The test kitchen can have several stations, but it is one kind of place with one set of rules.

## The decision

- Every environment has exactly one **type**: `prod` or `sandbox`. The word "nonprod" is not used.
- The type is recorded on every resource in the tag **`EnvironmentType`** (values `prod` or `sandbox`).
- The specific copy (`dev`, `test`, `uat`, `perf`, `demo`, `staging`, `pr<n>`, `prod`) goes in the tag `EnvironmentName`.
- Where a name would exceed a length limit, `sandbox` may be shortened to `sb`. Only there.

## What this means in practice

- Landing zones are named `…-prod` and `…-sandbox`, e.g. `cust-oc-sandbox`.
- A customer's dev and test run in their sandbox landing zone ([ADR 0007](./0007-customer-dev-and-test-share-sandbox-lz.md)).
- Cost reports and dashboards can split everything by `EnvironmentType` with only two values.

## Options we did not choose

| Option | Why not |
|---|---|
| Keep `nonprod` | Contradicts the requirements' "sandbox" and duplicates vocabulary |
| One type per environment name (dev, test, …) | Policies and network isolation only need two classes, and more types means more management groups |

## Technical details

- Tag key `EnvironmentType` replaces the earlier key `Environment` (N5).
- The top-level experiments management group is `mg-experiments`, so it doesn't clash with the `sandbox` type.
- Tokens: [`03-naming-conventions.md`](../03-naming-conventions.md) sections 3 and 9.
