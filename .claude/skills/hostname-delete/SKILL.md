---
name: hostname-delete
description: Delete a custom hostname from a stamp in tl-cloud-infrastructure — remove it from the tenant's hostnames in catalog/domains.yaml and, when it should point elsewhere again, add its outside record to global/edge/records/<zone>/ — as one PR opened with the user's own gh credentials; the stamp unbinds it and global/edge deletes its DNS records. Use when the user asks to delete, remove, detach, unbind or deprovision a hostname or domain from a stamp, or to point a domain back to another host.
disable-model-invocation: true
metadata:
  owner: infrastructure
---

# hostname-delete

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/hostname-delete/SKILL.md](../../../.agents/skills/hostname-delete/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
