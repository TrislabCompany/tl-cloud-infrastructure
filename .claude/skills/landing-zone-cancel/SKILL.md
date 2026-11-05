---
name: landing-zone-cancel
description: Cancel a landing zone's subscription in tl-cloud-infrastructure — after its hold (state decommissioned → cancelled), or at once without a hold (active → cancelled with hold_days 0), or end an experiment — and later open the clean-up PR that deletes landing-zones/<lz>.yaml and frees its /20 once Azure has deleted the subscription; each as one PR opened with the user's own gh credentials. Use when the user asks to cancel, delete, destroy, remove, deprovision or tear down a landing zone or its subscription, stop its costs, or clean up a cancelled landing zone.
metadata:
  owner: infrastructure
---

# landing-zone-cancel

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/landing-zone-cancel/SKILL.md](../../../.agents/skills/landing-zone-cancel/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
