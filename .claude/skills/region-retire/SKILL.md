---
name: region-retire
description: Retire a cloud region once nothing uses it — delete its hub (platform/azure/connectivity/hub-<code>.tf and its range in catalog/ipam.yaml), then set state retired in catalog/regions.yaml, never deleting the entry — as two dependent PRs in tl-cloud-infrastructure, opened with the user's own gh credentials. Use when the user asks to retire, remove, delete, deprovision, decommission or tear down a region or a hub.
metadata:
  owner: infrastructure
---

# region-retire

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/region-retire/SKILL.md](../../../.agents/skills/region-retire/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
