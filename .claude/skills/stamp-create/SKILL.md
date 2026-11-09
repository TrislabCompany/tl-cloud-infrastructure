---
name: stamp-create
description: Create a stamp (one Environment of an app, e.g. dev, staging or prod) in an existing landing zone of tl-cloud-infrastructure — write stamps/<lz>/<folder>/stamp.yaml, generate main.tf with the pinned tl-platform generator, lock the providers, choose its network mode (managed by default; a /27 in catalog/ipam.yaml only for vnet) and add its tenant with the default hostname <env>-<product>.trislab.com (public or protected) to catalog/tenants.yaml — as one PR opened with the user's own gh credentials. Use when the user asks to create, add, provision, deploy infrastructure for or set up a stamp, an environment such as dev, test, staging, demo or prod for an app, or a production stamp.
metadata:
  owner: infrastructure
---

# stamp-create

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/stamp-create/SKILL.md](../../../.agents/skills/stamp-create/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same.
