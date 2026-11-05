---
name: region-register
description: Register a new cloud region and build its hub, or build the hub of a region that is already registered without one — allow the region in catalog/regions.yaml with its code, reserve the hub's /20 in catalog/ipam.yaml, then write platform/azure/connectivity/hub-<code>.tf — as two dependent PRs in tl-cloud-infrastructure, opened with the user's own gh credentials. Use when the user asks to add, register, enable, provision or create a region, a hub or a new location, or wants a landing zone in a region that has no hub yet.
metadata:
  owner: infrastructure
---

# region-register

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/region-register/SKILL.md](../../../.agents/skills/region-register/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
