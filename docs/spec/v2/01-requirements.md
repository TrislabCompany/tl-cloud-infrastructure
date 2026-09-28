# 01 — Requirements

> Part of [spec v2](./README.md). Each requirement has an ID. [`02-architecture.md` section 10](./02-architecture.md#10-requirement-coverage) maps every ID to the part of the architecture that satisfies it.

## Scope

The platform hosts two kinds of workload:

- **Trislab products**: Trislab's own digital products, paid for by Trislab. Most are multi-tenant SaaS (e.g. `construction`, `hunting`), where one deployment serves many small customers. Company websites are single-tenant.
- **Customer deployments**: dedicated, single-tenant deployments for larger customers who need their own isolated environment. A customer may run one or several products, either standard Trislab products or applications built only for them.

## Functional requirements

| ID | Requirement |
|---|---|
| F1 | Host Trislab's own products: multi-tenant SaaS and company websites. |
| F2 | Host dedicated single-tenant customer deployments. A customer can run 1..n products, standard or customer-specific. |
| F3 | The same product must be deployable either **shared** (many tenants in one deployment) or **dedicated** (one customer) from the same infrastructure code. |
| F4 | Support these workload archetypes: container apps (the default; from scale-to-zero serverless up to dedicated compute); static SPAs, hosted on the same container platform rather than a separate hosting model; Kubernetes for complex microservice systems (e.g. ERP); event-driven functions. Data services: serverless PostgreSQL with branching for test copies, managed PostgreSQL for regional HA production, Redis-compatible cache. |
| F5 | **Multi-cloud**: Azure is the primary cloud. GCP serves customers who require it, and a GCP-only customer must have no dependency on Azure-side resources. AWS is out of scope. |
| F6 | Environments. Every environment has one of two types: **sandbox** or **prod**. Products: a *sandbox* tier (including on-demand ephemeral instances such as dev, uat, perf, demo and PR previews) and a *production* tier. Customers: *dev → test → prod*, where dev and test are of type sandbox. Each environment can be created and deleted independently. |
| F7 | **Build once, promote the artifact.** Dev deploys on every push to the default branch; test deploys on every release tag; prod deploys only by manual, approved promotion of the image digest already validated in test. Rollback means promoting the previous validated digest. There is no rebuild and no separate rollback pipeline. |
| F8 | Customer domains: Trislab creates and manages each customer's DNS zone. Sandbox URLs are `<env>.<customer-domain>`; production is the domain root. Delegating the registrar's NS records is the only step done by the customer. |
| F9 | Developers never create infrastructure. They declare their app's CPU, memory and compute profile in a `platform.yaml` within caps the platform enforces. App CI only builds images and points already-provisioned apps at new images and sizing. |
| F10 | Self-service through a developer portal (Backstage) comes later and is limited to sandbox. Production changes always go through the reviewed infrastructure pipeline. |
| F11 | A product can **graduate** from shared hosting to its own isolation boundary (own subscription, policy, budget, secrets) without any change to its app repository. |
| F12 | Customer IT admins get access scoped to their own environment only, onboarded as guest identities. **Regulated customers** (e.g. legal) additionally get advanced audit logging, encryption keys held by the customer, a restricted MFA-only Trislab admin group, and a dedicated log store when required. |
| F13 | Internal platform applications: developer portal (Backstage), ITSM with incident, change and SLA management (iTop), security scanning (image CVEs with Trivy, SBOM and licence tracking with Dependency-Track), monitoring (Prometheus, Grafana, alerts) and centralised logging (Loki). Each has a staging and a production instance where configuration needs safe testing. |

## Non-functional requirements

| ID | Requirement |
|---|---|
| N1 | **Everything as code, delivered by PR.** All infrastructure is OpenTofu. Every PR gets a plan comment, a cost estimate (Infracost), an IaC security scan (Prowler) and a policy-as-code check (OPA/conftest). Applies need an explicit approval. Production applies also need an approved iTop Change Request. A nightly drift check opens a GitHub Issue for any difference between code and cloud. |
| N2 | **No long-lived cloud secrets.** Automation authenticates with OIDC (Azure) and Workload Identity Federation (GCP). The only exceptions are vendors without federation support (Cloudflare, external SaaS API keys). Each of those is split into a read-only credential for plans and an edit credential available only to approved applies. |
| N3 | **Least privilege, small blast radius.** Plan identities are read-only. Apply identities run only after approval and are scoped to a single layer or a single landing zone. No single automation identity can change both the platform and every workload. |
| N4 | **Isolation.** No network traffic between production and sandbox. Customers are isolated from each other and from Trislab products. Each owner's secrets stay inside that owner's boundary. |
| N5 | **FinOps.** Every subscription or project has a budget with alerts to a shared FinOps channel, with an optional customer-specific recipient. Every resource carries the mandatory tags `Product`, `Customer`, `EnvironmentType`, `EnvironmentName`, enforced (untagged resources are rejected). Default to scale-to-zero compute and free tiers wherever possible. |
| N6 | **Data residency and region.** EU regions only. Azure: primary region `northeurope`, secondary `italynorth`. GCP: `europe-west8`. Other EU regions are added when a product needs them ([ADR 0016](./adr/0016-regions-added-when-needed.md)). Adding a region or moving a workload between regions means new instances (a hub, a landing zone, a stamp) plus a redeploy, not a redesign. |
| N7 | **Edge with no single point of failure.** Cloudflare is the primary edge (DNS, WAF, CDN, image optimisation, Zero Trust). Azure DNS and Azure Front Door are a live failover mirror. DNS is published to both providers. All sandbox environments and internal tools sit behind Zero Trust access automatically, with no per-environment setup. |
| N8 | **Central observability.** One central log store and one metrics stack across all products and customers. Queries filter by tenant, product and environment. Default log retention is 14 days. Alerts go to the developers' Slack channel. |
| N9 | **Supply chain.** GHCR is the single container registry for all products and customers, in any cloud. Every deployed image is CVE-scanned, and SBOMs are tracked. |
| N10 | **State.** Remote, locked, encrypted and versioned OpenTofu state. Each deployable unit has its own state. State is backed up across clouds. |
| N11 | **Manual only where unavoidable.** Humans act only to create the initial seed of privilege (tenant/org, first subscription/project, first state backend, the first automation identities) and for registrar NS delegation. Everything downstream is automated. |
| N12 | **Small team, MVP-first.** The design must start collapsed (few subscriptions, few templates) and grow by **adding instances** (landing zones, stamps, regions), never by restructuring what already exists. |
