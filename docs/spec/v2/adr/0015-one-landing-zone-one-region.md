# ADR 0015: A landing zone is in exactly one region

- **Status:** accepted
- **Date:** 2026-09-28

## The problem

A landing zone is like a company's rented office floor: it has its own lock, its own budget and its own list of who may enter. All floors start in one building, the `northeurope` region. Later some products have to move closer to their users, into another building in another city. We have to decide whether one floor can have rooms in several buildings, or whether each building gets its own floor.

Example: VBS Lawyers runs two production products, `construction` (stamp `vbs-con-prod`) and `application-x` (`vbs-apx-prod`). The users of `construction` are in Italy, so it runs in `italynorth`. The users of `application-x` are in Sweden, so it runs in a Swedish region. Those are two different buildings.

Sometimes two products stay in the same building but need different locks or budgets. For example, `construction` has to be regulated and `application-x` doesn't. Then the owner needs a second floor in the same building.

## The decision

A landing zone is in **exactly one region**, for good, and its name carries that region's code: `<scope>-<envtype>-<region>[-<nn>]`, e.g. `cust-vbs-prod-itn`. A stamp runs in the region of its landing zone.

An owner normally has one landing zone per environment type per region. A second one in the same region is created only when a **landing zone setting** has to differ. It gets the number `-02`, then `-03`, and so on, e.g. `cust-vbs-prod-neu-02`. The first one keeps its name without a number.

## What this means in practice

- An owner has one landing zone per environment type **per region**, plus a numbered one only where a landing zone setting has to differ. Everyone starts in `northeurope`, e.g. `cust-vbs-sandbox-neu` and `cust-vbs-prod-neu`.
- A landing zone in another region is created only when a stamp has to run there. In the example, VBS gets `cust-vbs-prod-itn` for `vbs-con-prod` and, once Sweden is added as a region, `cust-vbs-prod-sec` for `vbs-apx-prod`.
- Each landing zone has its own subscription, budget, deploy identity, access list, Key Vault and spoke network. All landing zones of one owner still share its invoice section (`is-cust-vbs`) and its admin group (`grp-cust-vbs-admins`), so the customer still gets one subtotal on the invoice.
- A landing zone setting is anything in `lz.yaml`: `archetype` (and so its policies), `budget`, `access`, the Key Vault and `observability`. A difference that `stamp.yaml` can express, such as sizing, zones, data services, secrets or template version, is not a reason for a second landing zone. Each stamp already has its own subnet, NSG, secret access and app-deploy identity.
- In the example, if `construction` must be regulated and `application-x` must not, both still in `northeurope`: `cust-vbs-prod-neu` keeps `archetype: prod-regulated` with `vbs-con-prod`, and `cust-vbs-prod-neu-02` gets `archetype: prod` with `vbs-apx-prod`. Both are billed to `is-cust-vbs`.
- Moving a stamp to another region means creating a new stamp in that region's landing zone and switching DNS. Data is moved by a restore or replication.
- A region must be allowed before any landing zone uses it ([ADR 0016](./0016-regions-added-when-needed.md)).

## Options we did not choose

| Option | Why not |
|---|---|
| One landing zone spanning several regions, with a spoke per region | Budget, access and Key Vault would mix regions. Stamps in other regions would reach the vault across regions, and moving the "home" region would move shared resources |
| Region code only on landing zones outside `northeurope` (e.g. `cust-vbs-prod` and `cust-vbs-prod-sec`) | Two naming rules for the same thing. With the code on every landing zone, the name always says where it is |
| Different landing zone settings per stamp inside one `lz.yaml` | The subscription, its management group and its policies, the budget, access and Key Vault all belong to the whole landing zone. Settings per stamp would only look separate |
| Product code in the name of the second landing zone (e.g. `cust-vbs-apx-prod-neu`) | Too long: the Key Vault `kv-cust-vbs-apx-prod-4821` would be 25 of 24 characters, and the GCP deploy service account `sa-lz-cust-vbs-apx-prod-deploy` 31 of 30 |
| Graduating the product (`prdt-apx-prod-neu`) | A graduated product is billed to `is-products`, but the customer pays for this one, so it belongs on `is-cust-vbs` |
| Numbering the first landing zone too (`cust-vbs-prod-neu-01`) | The name is also the subscription, state key, GitHub Environment and folder, so renaming an existing landing zone isn't practical |

## Technical details

- `lz.yaml` keeps one `region` and one `network.spoke_cidr`. The `landing-zone` module checks that `region` matches the region code in `name` (the last part, or the one before `-<nn>`). The IP plan gives one /20 per landing zone, so `-02` gets its own range.
- A second landing zone in the same region gets every name through `<lz>` like the first: e.g. `sub-cust-vbs-prod-neu-02`, `vnet-cust-vbs-prod-neu-02`, `spn-lz-cust-vbs-prod-neu-02-deploy`, GitHub Environment `lz-cust-vbs-prod-neu-02`, `landing-zones/cust-vbs-prod-neu-02.yaml` and `stamps/cust-vbs-prod-neu-02/`. `<nn>` starts at `02` and is never reused within an owner, environment type and region.
- `stamp.yaml` has no `region:` field. The generator takes the region from the landing zone's `lz.yaml`.
- Names that include the region code through `<lz>`: subscription `sub-cust-vbs-prod-itn`, spoke `vnet-cust-vbs-prod-itn`, state key `cust-vbs-prod-itn.tfstate`, identities `spn-lz-cust-vbs-prod-itn-deploy`, GitHub Environment `lz-cust-vbs-prod-itn`, budget `budget-cust-vbs-prod-itn`, and the folders `landing-zones/cust-vbs-prod-itn.yaml` and `stamps/cust-vbs-prod-itn/`.
- Two names leave the region code out because of length limits. The Key Vault is `kv-<scope>-<envtype>-<nnnn>`, e.g. `kv-cust-asg-prod-4821` (with the code it would be 25 of 24 characters). The GCP deploy service account is `sa-lz-<scope>-<envtype>-deploy` (with the code it would be 33 of 30). They leave out `-<nn>` for the same reason. The 4-digit suffix differs per state, so two Key Vaults of one owner never clash, whether they are in different regions or in the same region. A service account ID only has to be unique within its project.
- The two landing zones per owner in [ADR 0007](./0007-customer-dev-and-test-share-sandbox-lz.md) (`-sandbox` and `-prod`) count per region, plus any `-<nn>` landing zones. Examples in ADRs 0004, 0006, 0007 and 0011 show names without the region code; the current names are in [`03-naming-conventions.md`](../03-naming-conventions.md) section 7.3.
- Stamp codes stay unique across the repository. If one owner runs the same product and environment in two regions, `<nn>` tells them apart, e.g. `vbs-con-prod-01` and `vbs-con-prod-02`.
- Naming rules: [`03-naming-conventions.md`](../03-naming-conventions.md) sections 1 and 7.3. Network: [`02-architecture.md`](../02-architecture.md) section 4.
