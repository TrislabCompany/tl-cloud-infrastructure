---
name: stamp-destroy
description: Destroy a stamp after its data is exported — delete its folder, its range and its tenant and hostnames, as one PR; the pipeline plans the destroy and global deletes its DNS records, Access applications and Environment. Use when the user asks to destroy, delete, remove, deprovision, tear down or shut down a stamp or an app environment such as dev, staging, demo or prod.
disable-model-invocation: true
metadata:
  owner: infrastructure
---

# stamp-destroy

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/stamp-destroy/SKILL.md](../../../.agents/skills/stamp-destroy/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
