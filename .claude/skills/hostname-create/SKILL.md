---
name: hostname-create
description: Add a custom hostname (such as trislab.com or portal.example.com) to a stamp in tl-cloud-infrastructure — add it to the stamp's tenant in catalog/domains.yaml, public or protected, and, when the name moves from an outside host, delete its old A/AAAA/CNAME record from global/edge/records/<zone>/ in the same PR while keeping mail and other records — as one PR opened with the user's own gh credentials. Use when the user asks to add, create, attach, bind, point, move, switch or cut over a domain, apex or hostname to a stamp, or go live on a domain.
metadata:
  owner: infrastructure
---

# hostname-create

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/hostname-create/SKILL.md](../../../.agents/skills/hostname-create/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
