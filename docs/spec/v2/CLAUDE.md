# Writing rules for spec v2

These rules apply to every file in `docs/spec/v2/`. Follow them whenever you create or edit a spec document or ADR.

## Audience

The platform team and workload engineers at Trislab. ADRs must also be understandable by non-technical readers (management, sales, customers' contacts).

## Style

- Plain English. Short sentences. Present tense, describing the target design as fact.
- Tables for anything enumerable (requirements, names, options, identities).
- No history. Never reference v1, `docs/spec/v1/` or earlier designs. v2 is self-contained.
- Define an abbreviation the first time it appears in a file, unless it's in [`03-naming-conventions.md`](./03-naming-conventions.md) section 5.

## Structure

- Spec documents are named `NN-name.md` and numbered in reading order.
- Every file starts with its title, then `> Part of [spec v2](./README.md).` (from `adr/`: `../README.md`).
- Sections are numbered (`## 1. …`) so they can be referenced as "section N", e.g. `02 section 5`, `sections 2 and 3`. Never use the section sign character.
- Links are relative only.

## Consistency

- **Requirements.** IDs `F*` and `N*` in [`01-requirements.md`](./01-requirements.md) are the traceability key. A new or changed requirement updates the coverage table in [`02-architecture.md`](./02-architecture.md) section 10.
- **Names.** Every resource, landing zone, stamp, identity and tag follows [`03-naming-conventions.md`](./03-naming-conventions.md). A new abbreviation, token or owner code is added to 03 first. Environment types are only `prod` and `sandbox`, never "nonprod".
- **Decisions.** Every architectural decision becomes an ADR in [`adr/`](./adr/README.md), made from [`adr/0000-template.md`](./adr/0000-template.md).
  - Start with the plain-language problem: an everyday comparison plus one concrete example. Technical detail goes last.
  - An accepted ADR is never rewritten. Supersede it with a new ADR.
  - Never change or reverse a decision without the user's explicit approval. Propose it as a `proposed` ADR instead.
- **Open questions** live only in [`TODO.md`](./TODO.md#open-questions).

## Mermaid

- Quote every label that contains punctuation, spaces or symbols: `A["Label: text"]`.
- Never use reserved words (`end`, `graph`, `subgraph`) as node IDs.
- One diagram per concept. Keep diagrams small enough to read without zooming.
- Use the real names from 03 in diagrams.

## After every change

1. Update the status in [`TODO.md`](./TODO.md).
2. Update the documents table in [`README.md`](./README.md) if a file was added or renamed, and the ADR index in [`adr/README.md`](./adr/README.md) if an ADR was added or changed status.
3. Check that every relative link and `#anchor` resolves.
