# 04 — Network Foundation (Phase 3)

Run this **after** [03-cicd-workflows.md](./03-cicd-workflows.md). See [bootstrap process — Phase 3](../spec/05-bootstrap-process.md#phase-3--network-foundation) for what this phase builds, and [network architecture §1](../spec/02-network-architecture.md#1-topology) for the hub-spoke-vs-Virtual-WAN and no-Azure-Firewall-yet reasoning.

## No manual steps — by design

This is the first phase with nothing for a human to click in the Azure Portal or run ad hoc via the CLI. That's the point of Phases 0–2: once the state backend, the scoped service principals, and the CI/CD pipeline exist, the hub VNet (`vnet-tl-hub-platform-prod-weu`) is created entirely by merging a pull request that `apply-platform-foundation.yml` then applies via `spn-tl-github-platform-apply`.

**This phase creates the hub only — never a product spoke.** Every product spoke, sandbox or production, is created lazily by that *product's own* repo state (Backstage's direct apply for sandbox, `spn-tl-github-<product>-apply` for production), peering to the hub this phase created. See [`06-backstage-process.md`](../spec/06-backstage-process.md) (sandbox) and [`07-product-repo-process.md`](../spec/07-product-repo-process.md) (production) for that mechanism — it isn't this repo's job, and never becomes one.

If you find yourself needing to create or modify a VNet, subnet, peering, or NSG by hand in the Portal at this stage, that's a signal something upstream (state backend, SP scope, or the workflow itself) isn't working yet — go back to [01-azure-owner-bootstrap.md](./01-azure-owner-bootstrap.md) or [02-automation-identities.md](./02-automation-identities.md) rather than patching around it manually.

## Target topology

The hub is what this phase builds. The full topology diagram — showing product spokes, the platform-tools spoke, and dedicated-customer spokes eventually peering to it, built by other repos/processes at other times, not by this phase — lives in [`02-network-architecture.md` §1](../spec/02-network-architecture.md#1-topology), so it's maintained in one place. Multiple named environments sharing one Container Apps Environment/subscription per product per environment type is the "environment instance vs. subscription" decision in [`04-workloads.md`](../spec/04-workloads.md#1-compute-model). The platform-tools spoke (Backstage, and later Dependency-Track) is deliberately not reachable from Cloudflare's public edge like customer products are — it's reached only via Cloudflare Access (Zero Trust). Real network isolation between environment instances sharing one CAE requires a dedicated CAE (Process G, [`02-network-architecture.md` §5](../spec/02-network-architecture.md#5-network-isolation-within-a-shared-cae-process-g)) — sharing a CAE means sharing its network boundary.

## What to check instead

- `stacks/foundation/` plans and applies cleanly through the standard PR → `validate-platform-pull-request.yml` → merge → `apply-platform-foundation.yml` flow.
- The resulting hub VNet is named per the [naming convention](../spec/01-architecture-overview.md#4-naming--tagging-conventions), and nothing in this repo's state ever defines a product spoke.
- No NSG allows inbound traffic from outside Cloudflare's published IP ranges once [Cloudflare ingress](../spec/02-network-architecture.md#3-cloudflare-ingress) is in place.

## Next steps

First product onboarding, Cloudflare ingress cutover, and Backstage self-service enablement — runbooks for these get written when that work starts; see [`05-bootstrap-process.md`](../spec/05-bootstrap-process.md#what-comes-after-iteration-zero) for what's coming.

## Troubleshooting

| Issue | Action |
|---|---|
| Apply fails creating the hub VNet | Confirm `spn-tl-github-platform-apply`'s `Contributor` role at `mg-tl-platform` covers `sub-tl-platform-hub-eu` |
| Peering fails between hub and a product spoke | That peering is defined in the *product's own* apply, not here — confirm both VNets' address spaces don't overlap and both sides of the peering are defined in the same apply |
| Someone created a VNet manually in the Portal | Import it into state (`tofu import`) or delete and let the next apply recreate it — don't let manual and OpenTofu-managed resources drift silently |
| A product spoke shows up in this repo's plan | Wrong repo — product spokes belong in that product's own `tofu/`, never here (see "No manual steps" above) |
