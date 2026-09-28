# ADR 0011: One Azure invoice, with a section per customer

- **Status:** accepted
- **Date:** 2026-09-25

## The problem

Trislab pays for Azure as it goes and receives one invoice from Microsoft every month. Trislab then charges each customer separately, based on the contract that customer signed, using its own tools. To do that, the Azure invoice has to answer one simple question: how much did each customer cost us?

Think of a company credit card used for several clients. If the monthly statement is one long list of purchases, somebody has to sort every line by hand before any client can be billed. If the statement is already grouped by client, with a subtotal for each, the work is done. Example: customer OC has a sandbox and a production landing zone. The invoice should show a group "OC" with both subscriptions in it and one total. Trislab's own costs (platform, networking, internal products) should be in groups of their own, so they are never mixed with a customer's costs.

Every new customer also gets new subscriptions, and each one must be placed in the right group at the moment it is created. This has to happen automatically when a customer is onboarded, without a person working through the billing portal.

## The decision

Trislab keeps **one billing profile, so there is one invoice**. The invoice is divided into **invoice sections**: `is-platform` for the platform, `is-products` for Trislab's own products, and one `is-cust-<code>` per customer. When a landing zone is created, the `landing-zone` module places its subscription in its owner's section, and creates the section first if it doesn't exist yet. The pipeline identity `spn-landingzones-apply` holds the **Billing profile contributor** role so it can do this.

## What this means in practice

- The monthly invoice shows one subtotal per customer, with each of that customer's landing zones listed below it. Trislab re-charges customers from these subtotals with its own tools.
- Trislab's own costs are split into two sections: platform (shared services, networking, edge, experiments) and products.
- Onboarding a customer stays one pull request. The customer's invoice section appears automatically on the first apply.
- Nobody picks the section by hand. It follows from `owner:` in the landing zone's `lz.yaml`.
- A section is never deleted, even after the customer leaves, because old invoices refer to it.
- The billing role for `spn-landingzones-apply` is granted **once**, by a billing account owner, as part of the manual seed ([`02-architecture.md`](../02-architecture.md) section 12). Applies don't need a new grant each time.
- At least two named people always hold **Billing account owner**, so billing roles can always be granted or repaired without a Microsoft support request.

## Options we did not choose

| Option | Why not |
|---|---|
| A separate billing profile per customer | Every profile is a separate invoice with its own payment method. Trislab wants one invoice |
| Tags and cost reports only | The invoice itself stays one ungrouped list. Per-customer totals would depend on every resource being tagged correctly |
| One section per product | More sections to maintain. Products are Trislab's own cost and are re-charged differently from customers |
| A person creates each customer's section by hand | Adds a manual step to every onboarding (N11). Kept only as the fallback described below |
| Enterprise Agreement enrollment accounts | Trislab doesn't have an Enterprise Agreement |

## Technical details

**Billing structure** (checked 2026-09-25):

| Level | Value |
|---|---|
| Billing account | "Trislab billing account", Microsoft Customer Agreement (MCA), type Individual (pay-as-you-go) |
| Billing profile | "Trislab billing profile", EUR. The only profile that produces the Trislab invoice |
| Invoice sections | `is-platform` (today's "Trislab invoice section", renamed), `is-products`, `is-cust-<code>` |

**Which section a subscription goes into:**

| Subscriptions | Invoice section |
|---|---|
| `sub-platform*`, L0 global resources, `mg-experiments` subscriptions | `is-platform` |
| `products-sandbox`, `products-prod`, every `prdt-<code>-*` landing zone | `is-products` |
| `cust-<code>-sandbox`, `cust-<code>-prod` | `is-cust-<code>` |

The cost of individual tenants inside the shared `products` landing zones isn't split on the invoice. It comes from tag-filtered Cost Management views ([`02-architecture.md`](../02-architecture.md) section 9).

**Resources.** `landing-zone` creates the invoice section through the billing API (`Microsoft.Billing/billingAccounts/billingProfiles/invoiceSections`), using `is-cust-<code>` as both the resource name and the display name. It then creates the subscription with `azurerm_subscription` (subscription alias API) and this billing scope:

```text
/providers/Microsoft.Billing/billingAccounts/<ba>/billingProfiles/<bp>/invoiceSections/<is>
```

The billing account and profile IDs are GitHub Environment variables of the `landingzones` Environment. The section ID comes from the section resource. The subscription is placed in its management group with `azurerm_management_group_subscription_association`.

**Protection against accidental cancellation.** The `landingzones` layer sets the provider feature `subscription { prevent_cancellation_on_destroy = true }`. A subscription is only cancelled by the explicit `state: cancelled` step of decommissioning ([`02-architecture.md`](../02-architecture.md#decommissioning)).

**Permissions `spn-landingzones-apply` needs:**

| System | Role | Scope |
|---|---|---|
| Billing (MCA) | Billing profile contributor | "Trislab billing profile" |
| Azure RBAC | Management Group Contributor | `mg-landingzones`, `mg-decommissioned` |
| Azure RBAC | User Access Administrator, with a condition that only allows the landing zone role set | `mg-landingzones` |

**Order of the one-time grant.** `platform/azure/identity` creates `spn-landingzones-apply`. A billing account owner then grants the billing role through the billing role assignment REST API, because the portal can't select service principals. After that, the first `landingzones` apply runs. The assignment is tied to the identity's object ID, so it has to be granted again only if the identity is deleted and recreated. If it is missing, the apply fails with an authorization error when it creates the section or the subscription.

**Creator becomes Owner.** The identity that creates a subscription through the alias API is made its Owner. `spn-landingzones-apply` therefore holds Owner on every landing zone subscription, which is broader than the conditioned role above. It is also what lets it cancel a subscription at the end of decommissioning. Whether to keep or remove this assignment is decided in `05-landing-zones.md`.

**Fallback.** If this billing account type doesn't allow billing roles for service principals, a billing account owner creates each `is-cust-<code>` section by hand during onboarding. They grant `spn-landingzones-apply` **Azure subscription creator** on it, and the module then only looks the section up.

**Check before building:**

1. An MCA Individual billing account accepts a billing role assignment for a service principal.
2. Extra invoice sections can be created on "Trislab billing profile".
3. What exactly Billing profile contributor allows beyond sections and subscriptions (payment methods, invoices).
4. A subscription in `mg-decommissioned`, where all writes are denied, can still be cancelled by its Owner.
5. The subscription creation quota on the billing account covers two subscriptions per owner.

**GCP.** Google sends its own invoice, which is outside this decision. When GCP is built ([ADR 0008](./0008-gcp-built-on-first-customer.md)), projects carry the same `customer` label, and billing export grouped by label gives the per-customer view.
