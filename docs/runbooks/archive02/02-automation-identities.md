# 02 — Segregated Automation Identities (Phase 1)

Run this **after** [01-azure-owner-bootstrap.md](./01-azure-owner-bootstrap.md). See [governance & identity §2](../spec/03-governance-identity.md#2-identity-model) for the full identity model and why it rejects a single shared service principal.

Three service principals plus one managed identity, each scoped to the narrowest management group it needs. `spn-tl-github-platform-apply` and `spn-tl-github-landingzones-apply` are split because they touch different management groups (a mistake caught and fixed after Phase 3 turned out to need both) — see [governance & identity §2](../spec/03-governance-identity.md#2-identity-model) for why. All three SPs authenticate via OIDC federated credentials — no long-lived client secret is used by any of them. The identity uses no credential at all.

| Identity | Purpose | Mechanism | RBAC role | Scope |
|---|---|---|---|---|
| `spn-tl-github-platform-plan` | Read-only PR plan/validate | Entra App Registration, OIDC federated credential | `Reader` | `mg-tl-platform` and `mg-tl-landingzones` |
| `spn-tl-github-platform-apply` | Apply hub/LAW/platform-tools changes | Entra App Registration, OIDC federated credential | `Contributor` only | `mg-tl-platform` (gated by branch protection on `main`, not a GitHub Environment — see [governance & identity §2](../spec/03-governance-identity.md#2-identity-model)) |
| `spn-tl-github-landingzones-apply` | Create product management groups/initial subscriptions — never a spoke | Entra App Registration, OIDC federated credential | `Contributor` only | `mg-tl-landingzones` |
| `id-tl-backstage-scaffolder` | Self-service sandbox provisioning | User-Assigned Managed Identity — created standalone here, attached to the Backstage Container App in Phase 6 | `Contributor` | `mg-tl-workloads-sandbox` only |

None of these ever receive `Owner` or `User Access Administrator` — they cannot modify RBAC or policy, only the resource types their role permits. Per-product production identities (`spn-tl-github-<product>-apply`) aren't part of this platform-bootstrap runbook — they're registered per product as described in [`docs/spec/07-product-repo-process.md` §5](../spec/07-product-repo-process.md#5-deployment-into-azure-container-apps-process-c).

## Worked example — `spn-tl-github-platform-apply`

**CLI:**
```bash
az ad app create --display-name "spn-tl-github-platform-apply"
APP_ID=$(az ad app list --display-name "spn-tl-github-platform-apply" --query "[0].appId" -o tsv)
az ad sp create --id $APP_ID

az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main-branch-apply",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:TrislabCompany/tl-cloud-infrastructure:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope "/providers/Microsoft.Management/managementGroups/mg-tl-platform"
```

**Portal:**
1. **Microsoft Entra ID** → **App registrations** → **New registration** → name `spn-tl-github-platform-apply`, single tenant.
2. **Certificates & secrets** → **Federated credentials** → **Add credential** → scenario "GitHub Actions deploying Azure resources" → Organization `TrislabCompany`, Repository `tl-cloud-infrastructure`, Entity type "Branch", Branch name `main`.
3. Go to management group `mg-tl-platform` → **Access control (IAM)** → **Add role assignment** → Role `Contributor` → assign to the `spn-tl-github-platform-apply` app.

## Repeat for the other two SPs

Same three-step pattern (App registration → federated credential → role assignment), substituting:

**`spn-tl-github-platform-plan`**
- Federated credential subject: `repo:TrislabCompany/tl-cloud-infrastructure:pull_request` (Entity type "Pull request" in the Portal) — triggers on PR events, not a merge to `main`
- Role: `Reader`, assigned **twice** — once at `mg-tl-platform`, once at `mg-tl-landingzones` — since this one identity plans changes across both stacks

**`spn-tl-github-landingzones-apply`**
- Same steps as `spn-tl-github-platform-apply` above, same federated credential subject (`repo:TrislabCompany/tl-cloud-infrastructure:ref:refs/heads/main` — a federated-credential subject isn't required to be unique across SPs; `apply-platform-landingzones.yml`'s workflow YAML simply logs in as this client-id instead)
- Role: `Contributor` at `mg-tl-landingzones`, not `mg-tl-platform`

## Worked example — `id-tl-backstage-scaffolder` (Managed Identity, not an App Registration)

No federated credential, no client secret, nothing to rotate — a Managed Identity's token exchange is handled transparently by Azure for any compute it's attached to.

**CLI:**
```bash
az identity create \
  --name id-tl-backstage-scaffolder \
  --resource-group rg-tl-platform-state-weu

PRINCIPAL_ID=$(az identity show \
  --name id-tl-backstage-scaffolder \
  --resource-group rg-tl-platform-state-weu \
  --query principalId -o tsv)

az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/providers/Microsoft.Management/managementGroups/mg-tl-workloads-sandbox"
```

**Portal:**
1. RG `rg-tl-platform-state-weu` → **+ Create** → "User Assigned Managed Identity" → name `id-tl-backstage-scaffolder`, region West Europe.
2. Management group `mg-tl-workloads-sandbox` → **Access control (IAM)** → **Add role assignment** → Role `Contributor` → **Managed identity** → select `id-tl-backstage-scaffolder`.

This identity is only *created* here — it isn't attached to any compute yet. Attaching it to the Backstage Container App (`az containerapp identity assign --user-assigned id-tl-backstage-scaffolder`) happens in Phase 6, once that Container App exists.

## Verify

- `az role assignment list --assignee <appId-or-principalId> --all` shows exactly one role, at exactly the scope in the table above, for each identity.
- No identity shows `Owner` or `User Access Administrator` anywhere: `az role assignment list --all --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='User Access Administrator']"`.

## Next steps

[03-cicd-workflows.md](./03-cicd-workflows.md) — wire these SPs into GitHub Actions.

## Troubleshooting

| Issue | Action |
|---|---|
| `AADSTS70021` / invalid client | Federated credential subject must match the repo/ref/entity type exactly (applies to the two SPs, not the Managed Identity) |
| Role assignment fails | Confirm you're still within your PIM-activated `Owner` window from Phase 0 |
| `id-tl-backstage-scaffolder` can reach prod resources | Scope error — it must be `mg-tl-workloads-sandbox` only, re-check the role assignment scope |
