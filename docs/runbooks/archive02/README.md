# Runbooks

Step-by-step execution guides (CLI **and** Portal UI for every manual step) for the bootstrap process defined in [`docs/spec/05-bootstrap-process.md`](../spec/05-bootstrap-process.md) — Process 1 of the three-process spec set indexed in [`docs/spec/README.md`](../spec/README.md) (bootstrap → Backstage self-service → product-repo mechanics). That document explains *what* and *why*, phase by phase; these explain exactly *how*, in the same order.

Read/run in this order:

0. [00-repository-baseline.md](./00-repository-baseline.md) — Prerequisite: confirm the three repos (already created, public) and add the branch protection they're currently missing.
1. [01-azure-owner-bootstrap.md](./01-azure-owner-bootstrap.md) — Phase 0: the one-time human bootstrap (management group, subscription, state storage, Log Analytics, bootstrap Key Vault).
2. [02-automation-identities.md](./02-automation-identities.md) — Phase 1: registering the scoped service principals (GitHub plan, GitHub apply, Backstage scaffolder) with OIDC federated credentials.
3. [03-cicd-workflows.md](./03-cicd-workflows.md) — Phase 2: wiring the GitHub Actions workflows and the branch-protection apply gate.
4. [04-network-foundation.md](./04-network-foundation.md) — Phase 3: hub-spoke network, fully OpenTofu-managed — confirms nothing manual is left.

Phases past network foundation — first product onboarding, Cloudflare ingress cutover, Backstage self-service enablement (see [`docs/spec/06-backstage-process.md`](../spec/06-backstage-process.md)) — don't have runbooks yet; they get written when that work actually starts.
