---
name: landing-zone-create
description: Create an application landing zone in tl-cloud-infrastructure — choose its scope (products, cust-<code>, prdt-<code>), environment type (prod or sandbox) or experiment, region with a hub, archetype, budget and access; reserve its /20 in catalog/ipam.yaml; write landing-zones/<lz>.yaml; add the prod data access groups — as one PR opened with the user's own gh credentials. Use when the user asks to create, add, provision, set up or build a landing zone, a subscription for products or a customer, a prod or sandbox environment class, or an experiment subscription.
metadata:
  owner: infrastructure
---

# landing-zone-create

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/landing-zone-create/SKILL.md](../../../.agents/skills/landing-zone-create/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
