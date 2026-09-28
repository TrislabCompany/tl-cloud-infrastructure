# ADR 0009: Template upgrades roll out ring by ring

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Every product and customer deployment (stamp) is built from a shared template. When we improve the template, all stamps should get the improvement. If we updated them all at once and the change had a bug, every customer would be affected at the same moment.

It's like a new recipe in a restaurant chain: you try it in one branch first, then a few more, and only then everywhere.

## The decision

Each stamp states exactly which template version it uses. A new version is rolled out in **rings**, one ring at a time: Trislab's own sandbox → Trislab's own production → customer sandboxes → customer production → regulated customers last. Each ring is a normal, reviewed change. The next ring starts only after the previous one succeeded.

## What this means in practice

- Problems show up first on our own environments, not on customers.
- A failed ring stops the rollout; later rings stay on the old version untouched.
- The upgrade PRs are opened automatically (Renovate). People review and approve them.

## Options we did not choose

| Option | Why not |
|---|---|
| All stamps always use the latest template | One bug reaches every customer at once |
| Manual upgrades whenever someone remembers | Stamps drift apart and old versions pile up |

## Technical details

[`02-architecture.md`](../02-architecture.md) section 5 (rollout rings) and section 11 (template rollout scenario).
