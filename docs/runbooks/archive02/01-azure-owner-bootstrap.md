# 01 — Azure Owner Bootstrap (Phase 0)

Prerequisites for OpenTofu to manage Trislab's cloud infrastructure. Complete this guide **before** any `tofu apply`. See [bootstrap process — Phase 0](../spec/05-bootstrap-process.md#phase-0--human-owner-bootstrap) for the "why" behind each resource.

**Audience:** a real Entra ID user with (or able to activate) the `Owner` role at the Tenant Root Group.

## What you create manually vs. OpenTofu

Only what OpenTofu cannot create for itself is manual — everything else, including the Log Analytics Workspace, is created by the first `tofu apply` itself. There is no bootstrap Key Vault: the identity model never creates a client secret anywhere (this apply uses your own `az login`; every SP in Phase 1 uses only federated credentials), so there's nothing for one to hold.

| Resource | Created by |
|---|---|
| Tenant Root Group | Azure (exists) |
| `mg-tl-platform` management group | **Manual (this guide)** |
| `sub-tl-platform-hub-eu` subscription | **Manual (this guide)** |
| State storage account + container | **Manual (this guide)** |
| `log-tl-platform-weu` Log Analytics Workspace | OpenTofu (Step 0.5's first apply, part of `stacks/foundation`) |
| `mg-tl-landingzones` and everything under it | OpenTofu (from Step 0.5 onward) |

No service principal is created in this phase — see [02-automation-identities.md](./02-automation-identities.md) for Phase 1.

## Step 0.1 — Activate Owner via PIM

PIM activation has no simple CLI one-liner; the Microsoft Graph route is materially more complex than the Portal button, so Portal is primary here.

**Portal (primary):**
1. Sign in to [Azure Portal](https://portal.azure.com).
2. Open **Microsoft Entra Privileged Identity Management** → **Azure resources**.
3. Select the Tenant Root Group → find your eligible `Owner` assignment → **Activate**.
4. Provide a justification and a time-boxed duration.

**CLI (advanced/optional):**
```bash
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests" \
  --body '{
    "action": "selfActivate",
    "principalId": "<your-object-id>",
    "roleDefinitionId": "<owner-role-id>",
    "directoryScopeId": "/",
    "justification": "Iteration Zero bootstrap"
  }'
```

## Step 0.2 — Create `mg-tl-platform`

**CLI:**
```bash
az account management-group create \
  --name mg-tl-platform \
  --display-name "Trislab Platform" \
  --parent mg-tl
```

**Portal:**
1. Search **Management groups**.
2. Select `mg-tl` (root) → **+ Add management group**.
3. Management group ID: `mg-tl-platform`; Display name: `Trislab Platform`.
4. Save, confirm it appears nested under `mg-tl`.

## Step 0.3 — Create/assign `sub-tl-platform-hub-eu`

**CLI:**
```bash
az account alias create --name sub-tl-platform-hub-eu-alias \
  --billing-scope "<EA_OR_MCA_BILLING_SCOPE_ID>" \
  --display-name "sub-tl-platform-hub-eu"

az account management-group subscription add \
  --name mg-tl-platform \
  --subscription "<SUBSCRIPTION_ID>"
```

**Portal:**
1. **Subscriptions** → **+ Add** (or reuse an existing one) → display name `sub-tl-platform-hub-eu`, select the billing account/agreement.
2. **Management groups** → `mg-tl-platform` → **Subscriptions** tab → **+ Add** → select `sub-tl-platform-hub-eu` → Save.

Record the subscription ID and tenant ID — both are needed later for `.tfvars` and GitHub Actions repository variables.

## Step 0.4 — State storage

`rg-tl-platform-state-weu` + `sttlplatformstateweu01`. Standard_GRS is the cheapest durable, cross-region-redundant option for a critical state file; native blob-lease locking avoids paying for a separate locking service.

**CLI:**
```bash
az group create --name rg-tl-platform-state-weu --location westeurope

az storage account create \
  --name sttlplatformstateweu01 \
  --resource-group rg-tl-platform-state-weu \
  --location westeurope \
  --sku Standard_GRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true

az storage account blob-service-properties update \
  --account-name sttlplatformstateweu01 \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30

az storage container create \
  --account-name sttlplatformstateweu01 \
  --name tfstate \
  --auth-mode login
```

**Portal:**
1. **Resource groups** → **+ Create** → name `rg-tl-platform-state-weu`, region West Europe.
2. Inside the RG → **+ Create → Storage account** → name `sttlplatformstateweu01`, redundancy GRS, TLS 1.2 enforced.
3. **Networking** tab → disable public access (except authorized IPs, if needed during bootstrap).
4. **Data protection** tab → enable blob soft delete (30 days) and versioning.
5. **Containers** blade → **+ Container** → name `tfstate`, access level Private.

Replace `sttlplatformstateweu01` if the name is globally taken (it must be unique across all of Azure).

## Step 0.5 — Adopt state under OpenTofu

With Steps 0.1–0.4 complete, run the first apply locally under your own `az login` session (no SP exists yet). `stacks/foundation` creates `log-tl-platform-weu` (Pay-as-you-go, 30-day retention — avoid Commitment Tiers until ingestion volume justifies them) as part of this apply, along with `mg-tl-landingzones` and everything under it — nothing about creating a Log Analytics Workspace needs elevated permissions your Owner session doesn't already have, so there's no reason to do it by hand first.

```bash
az login
az account set --subscription "<sub-tl-platform-hub-eu ID>"

cd stacks/foundation
tofu init -backend-config="../../backends/platform-foundation.azure.hcl"
tofu plan  -var-file="../../environments/platform-hub-eu.tfvars"
tofu apply -var-file="../../environments/platform-hub-eu.tfvars"
```

From here on, nothing further in Phase 0's scope is created by hand.

## Stop here

Do not manually create `mg-tl-landingzones`, product management groups, or product subscriptions — that is OpenTofu's job from this point forward.

## Next steps

1. [02-automation-identities.md](./02-automation-identities.md) — register the scoped service principals.
2. [03-cicd-workflows.md](./03-cicd-workflows.md) — wire up GitHub Actions.

## Troubleshooting

| Issue | Action |
|---|---|
| Storage account name already taken | Pick a new `<seq>` suffix, e.g. `sttlplatformstateweu02` |
| PIM activation not available | Confirm you have an eligible (not just active-elsewhere) `Owner` assignment at Tenant Root Group |
| `tofu apply` fails with auth error | Confirm `az account show` reflects `sub-tl-platform-hub-eu` and your session hasn't expired |
