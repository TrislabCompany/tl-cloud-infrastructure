---
paths:
  - "catalog/**"
  - "landing-zones/*.yaml"
  - "stamps/**/stamp.yaml"
  - "global/edge/records/**"
---

# Catalogs and data files

Checked by: `python .agents/skills/_shared/check-catalog.py` (the `catalog` rego rules, as the plan runs them) and the plan of every root that reads the changed file. Each file's header comment is its schema; `stamp.yaml` has `stamp.schema.json` in `tl-platform`.

These files are the contract between the people who onboard tenants and products and every layer that reads them. A wrong entry changes live resources.

- **The header comment is the schema.** A new field is described there first: its name, its type, whether it is required, and what reads it. Keep the description and the rego rule in `policy/catalog.rego` in the same PR.
- **Change only by adding.** A new optional field, a new entry. A field is never renamed or removed while a root reads it: add the new one, move the readers, then remove the old one, each a PR.
- **Entries are kept** (AGENTS.md "Registers keep their entries"): retire or archive, never delete. Codes, slugs and `-<nn>` numbers are never reused, and an id never changes once a root uses it.
- **Edit by lines, not by re-serialising** (`_shared/pr.md`): keep comments, order and quoting; LF line endings.
- **One change per PR when there is an order:** a landing zone, then its stamps (AGENTS.md "How a change is applied").
- Values are lower-case kebab-case ids, ISO dates, and the region and owner codes of AGENTS.md "Names". No personal data: a group's members are added by hand in Entra ID.
