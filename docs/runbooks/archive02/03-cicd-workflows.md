# 03 — CI/CD Workflows (Phase 2)

Run this **after** [02-automation-identities.md](./02-automation-identities.md). See [bootstrap process — Phase 2](../spec/05-bootstrap-process.md#phase-2--cicd-enablement) for why Trivy, GitHub-hosted runners, and branch protection (not a GitHub Environment) are used.

## Workflows

Three purpose-named workflows in `tl-cloud-infrastructure/.github/workflows/` — never a generic `opentofu.yml` or `ci.yml`. Two apply workflows, not one, because they touch different management groups (see [governance & identity §2](../spec/03-governance-identity.md#2-identity-model) for why the identities behind them are split):

- **`validate-platform-pull-request.yml`** — triggers on `pull_request` and manual `workflow_dispatch`. Jobs: `fmt-and-validate`, `plan` (using `spn-tl-github-platform-plan`), `trivy-scan` (skippable via a `workflow_dispatch` boolean input, so it can be disabled or re-run manually per the original requirement).
- **`apply-platform-foundation.yml`** — triggers on `push` to `main`, paths-filtered to `stacks/foundation/**`. Uses `spn-tl-github-platform-apply` (`mg-tl-platform`). Creates/updates the hub VNet, `log-tl-platform-weu`, and the platform-tools CAE — never a product spoke.
- **`apply-platform-landingzones.yml`** — triggers on `push` to `main`, paths-filtered to `governance/**`. Uses `spn-tl-github-landingzones-apply` (`mg-tl-landingzones`). Creates product management groups and initial subscriptions only — the product's own spoke VNet is that product's own repo's job, not this one's.

Neither apply workflow uses an `environment:` key — the gate is the branch protection rule from [00-repository-baseline.md](./00-repository-baseline.md): by the time anything reaches `main`, it has already been through a reviewed PR. All three authenticate via OIDC (`azure/login@<sha>` with `client-id`/`tenant-id`/`subscription-id` — no `client-secret` input anywhere in any workflow file, and pinned to a commit SHA, not a floating tag — see the security settings below).

## Manual step: branch protection on `main`

This is the actual apply gate. If you completed [00-repository-baseline.md](./00-repository-baseline.md) already, it's done — this is included here too so this runbook stands on its own.

**CLI:**
```bash
gh api repos/TrislabCompany/tl-cloud-infrastructure/branches/main/protection -X PUT \
  -H "Accept: application/vnd.github+json" \
  -f 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'required_status_checks=null' \
  -F 'enforce_admins=true' \
  -F 'restrictions=null'

gh secret set AZURE_CLIENT_ID_FOUNDATION    --body "<spn-tl-github-platform-apply appId>"
gh secret set AZURE_CLIENT_ID_LANDINGZONES  --body "<spn-tl-github-landingzones-apply appId>"
gh variable set AZURE_TENANT_ID       --body "<tenant id>"
gh variable set AZURE_SUBSCRIPTION_ID --body "<sub-tl-platform-hub-eu id>"
```
Note: no `--env` flag anywhere — these are repository-level secrets/variables, not environment-scoped, so they work identically regardless of the repo's visibility or GitHub plan. Two distinct client-ID secrets because two different SPs run in this one repo — `apply-platform-foundation.yml` references `AZURE_CLIENT_ID_FOUNDATION`, `apply-platform-landingzones.yml` references `AZURE_CLIENT_ID_LANDINGZONES`.

**UI:**
1. Repo → **Settings** → **Branches** → **Add branch protection rule** → `main` → require a pull request with ≥1 approval (see [00-repository-baseline.md](./00-repository-baseline.md) for the full steps).
2. Repo → **Settings** → **Secrets and variables** → **Actions** (the repository-level tab, not an environment tab) → add `AZURE_CLIENT_ID_FOUNDATION` and `AZURE_CLIENT_ID_LANDINGZONES` (secrets) and `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` (variables) — do **not** add an `AZURE_CLIENT_SECRET`; OIDC is the only authentication path.

Per-product production workflows (`spn-tl-github-<product>-apply`, in each Backstage-generated product repo) follow the same pattern: repository-level secrets/variables, no GitHub Environment. `id-tl-backstage-scaffolder` itself is a Managed Identity, not a GitHub Actions identity — see [`docs/spec/03-governance-identity.md` §2](../spec/03-governance-identity.md#2-identity-model).

## Manual step: public-repo security settings

Both repos are public ([architecture overview §7](../spec/01-architecture-overview.md#7-public-repository-security-posture)) — these settings are what makes that safe, not assumed.

**CLI (`gh`):**
```bash
gh api repos/TrislabCompany/tl-cloud-infrastructure -X PATCH \
  -f security_and_analysis[secret_scanning][status]=enabled \
  -f security_and_analysis[secret_scanning_push_protection][status]=enabled

gh api repos/TrislabCompany/tl-cloud-infrastructure/actions/permissions/workflow -X PUT \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false
```

**UI:**
1. Repo → **Settings** → **Code security** → enable **Secret scanning** and **Push protection**.
2. Repo → **Settings** → **Actions** → **General** → **Fork pull request workflows from outside collaborators** → require approval for first-time contributors (at minimum).

Repeat for `tl-platform` and every product repo. Two more things enforced in the workflow files themselves, not a repo setting: every third-party action pinned to a commit SHA (`azure/login@<sha>`, not `@v2`), and an explicit minimal `permissions:` block (`contents: read` by default) in every workflow — check both when reviewing a new or changed workflow file.

## Reading `tl-platform` as a module source

All three workflows call `tofu init`, which clones `tl-platform` per the git-ref module source ([architecture overview §5](../spec/01-architecture-overview.md#module-publishing--consumption)). While `tl-platform` is public, this needs **no extra step** — the default `GITHUB_TOKEN` isn't even involved; a public repo is clonable by any workflow. If `tl-platform` moves to private before its consumers do, add each consuming repo to `tl-platform`'s **Settings → Actions → General → Access** list at that time (see [00-repository-baseline.md](./00-repository-baseline.md)) — nothing to add here today.

## Verify

- A PR against `main` triggers `validate-platform-pull-request.yml` and shows a plan output + Trivy results (or a note that Trivy was skipped, if the dispatch input was set).
- A direct push to `main` (bypassing a PR) is rejected by GitHub, not just discouraged.
- Merging an approved PR to `main` triggers `apply-platform-foundation.yml` or `apply-platform-landingzones.yml` (whichever path changed, possibly both), which run immediately — there is no separate approval pause at apply time, because the approval already happened at merge time.
- No secret named `AZURE_CLIENT_SECRET` exists anywhere in the repo's secrets/variables, and none of `AZURE_CLIENT_ID_FOUNDATION`/`AZURE_CLIENT_ID_LANDINGZONES`/`AZURE_TENANT_ID`/`AZURE_SUBSCRIPTION_ID` are environment-scoped.

## Next steps

[04-network-foundation.md](./04-network-foundation.md) — the first fully OpenTofu-managed phase.

## Troubleshooting

| Issue | Action |
|---|---|
| `Login succeeds but apply denied` | Check the `Contributor` role assignment at `mg-tl-platform` for `spn-tl-github-platform-apply`, or at `mg-tl-landingzones` for `spn-tl-github-landingzones-apply` — whichever workflow ran |
| Plan works locally but CI fails | Verify the four repository-level variables/secrets match the actual tenant/subscription IDs, and that each workflow references the right client-ID secret |
| Merge doesn't require approval | Check the branch protection rule on `main` (`required_pull_request_reviews`, `enforce_admins`) — not a GitHub Environment, which this design doesn't use |
| `tofu init` can't clone `tl-platform` | Confirm `tl-platform` is still public; once private, confirm the consumer repo is on `tl-platform`'s Actions Access list |
