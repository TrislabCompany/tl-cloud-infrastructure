---
name: landing-zone-decommission
description: Decommission a landing zone with a hold in tl-cloud-infrastructure, once its stamps are destroyed — set state decommissioned, decommissioned_on and hold_days in landing-zones/<lz>.yaml and, for prod, delete its data access groups — as one PR opened with the user's own gh credentials; the subscription and data stay until landing-zone-cancel. Also takes a decommissioned landing zone back to active during its hold. Use when the user asks to decommission, retire, remove, delete, deprovision, tear down or shut down a landing zone and its data may still be needed.
metadata:
  owner: infrastructure
---

# landing-zone-decommission

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/landing-zone-decommission/SKILL.md](../../../.agents/skills/landing-zone-decommission/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
