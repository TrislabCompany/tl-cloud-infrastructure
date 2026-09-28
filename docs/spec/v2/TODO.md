# TODO — spec v2 status and next steps

> Part of [spec v2](./README.md). Updated with every change to the spec. Statuses: **done** · **next** (being worked on now) · **todo**.

## Documents

| # | Item | Status |
|---|---|---|
| 01 | [`01-requirements.md`](./01-requirements.md): functional and non-functional requirements | done |
| 02 | [`02-architecture.md`](./02-architecture.md): target architecture | done |
| 03 | [`03-naming-conventions.md`](./03-naming-conventions.md): names for every layer, tags, limits | done |
| — | [`adr/`](./adr/README.md): decision records 0001–0022 and 0024–0029 accepted; 0013 superseded by 0025; 0023 rejected; 0030–0034 proposed | 0030–0034 wait for approval |
| — | [`CLAUDE.md`](./CLAUDE.md): writing rules for agents | done |
| — | Resolve the [open questions](#open-questions) below | done for now (6–8 deferred until their triggers) |
| 04 | [`04-repository-structure.md`](./04-repository-structure.md): full annotated repository tree with every product, customer and environment | done |
| 05 | [`05-landing-zones.md`](./05-landing-zones.md): `landing-zone` module spec, `lz.yaml` schema, what an apply creates, adding a region, landing zone lifecycle | done (depends on open questions 6–7) |
| 06 | [`06-stamp-templates.md`](./06-stamp-templates.md): stamp template contract, `stamp.yaml` schema, `zone_redundant` per service, `aca-app` v1 | done (`db-postgres` and private endpoints wait for open question 7) |
| 07 | [`07-catalog-and-ipam.md`](./07-catalog-and-ipam.md): tenant catalog and IP plan schema | done |
| 08 | [`08-pipeline.md`](./08-pipeline.md): path → layer → identity mapping, gates, drift, which parts of `tfstate-stamps` each deploy identity can read and write, re-applying stamps after a `global` or `landingzones` apply that writes their DNS records or credentials ([ADR 0026](./adr/0026-vendor-credentials-through-lz-environment.md), [ADR 0027](./adr/0027-global-edge-writes-stamp-dns-records.md)) | done (depends on proposed ADRs 0030–0033) |
| 09 | [`09-bootstrap.md`](./09-bootstrap.md): manual seed runbook | done (sections 6–9 depend on proposed ADRs 0031–0034) |
| 10 | [`10-roadmap.md`](./10-roadmap.md): build order, from clearing the tenant to the customer pilot and what follows | done. Next: detailed steps per phase |

## Open questions

These are the next thing to address. Resolving a question means writing a new ADR and removing its row. Numbers are not reused, so references to a question stay valid. A **deferred** question is not needed for the initial build; it stays here until its trigger happens.

| # | Question | Why it matters | Options | Resolves into |
|---|---|---|---|---|
| 6 | **Deferred until the first region beyond N6.** What does the service check before adding a region contain? | [ADR 0016](./adr/0016-regions-added-when-needed.md) requires it but lists nothing to check | A checklist per stamp template in 06, including availability zones ([ADR 0017](./adr/0017-availability-zones-per-stamp.md)); a script against the Azure resource provider API | ADR, when the first new region is added ([ADR 0023](./adr/0023-region-service-check-from-template-requirements.md) rejected as premature) |
| 7 | **Deferred until the first stamp template with a private endpoint.** Who lets a stamp's private endpoint write its DNS record into a `privatelink.*` zone? | A private endpoint's DNS zone group needs `Microsoft.Network/privateDnsZones/join/action` on the zone for `spn-lz-<lz>-deploy`, and nobody grants it yet ([ADR 0020](./adr/0020-landing-zone-links-private-dns-zones.md)) | `landing-zone` module grants it on the zones the landing zone's templates use; `connectivity` grants a join-only custom role on `rg-platform-dns` to every deploy identity; Azure Policy `DeployIfNotExists` creates the zone group | ADR, then 06, when the first template uses a private endpoint |
| 8 | **Deferred until the first stamp with `db-neon`.** How is a stamp's state kept from any PR's plan job? | Plan identities trust the `pull_request` subject, so any repository writer's PR can sign in as `spn-lz-<lz>-plan` and read that landing zone's stamp states. The Neon provider stores the role password there ([ADR 0026](./adr/0026-vendor-credentials-through-lz-environment.md)), which ADR 0026 assumes only the deploy identity can read ([08 section 7](./08-pipeline.md#7-state-access)) | Keep secrets out of stamp state (the `global` fallback of ADR 0026, or a password the stamp rotates and never outputs); plan stamps inside a reviewer-free Environment `lz-<lz>-plan` limited to the stamp's CODEOWNERS; accept it, because every repository writer is a Trislab engineer | ADR, before the first stamp uses `db-neon` |

## Housekeeping

- Close the unused billing profile "biling profile test": a second profile means a second invoice ([ADR 0011](./adr/0011-one-invoice-with-a-section-per-owner.md)). Manual, by a billing account owner. It has no subscriptions and no invoices (checked 2026-09-28).
- Rename the invoice section "Trislab invoice section" to `is-platform` ([ADR 0011](./adr/0011-one-invoice-with-a-section-per-owner.md)). Needed before the seed ([09 section 4](./09-bootstrap.md#4-management-groups-and-sub-platform)).
- Approve or change the proposed ADRs 0030–0034. Sections of 08, 09 and 10 depend on them.
