# 00 — Repository Baseline (Prerequisite)

Run this **before** [01-azure-owner-bootstrap.md](./01-azure-owner-bootstrap.md). See [bootstrap process — Prerequisite](../spec/05-bootstrap-process.md#prerequisite--repository-baseline) for why this exists.

The three repos already exist — this is not a creation step. It confirms their current state and closes the one real gap: no branch protection on `main`.

## Step 1 — Confirm what exists

| Repo | Visibility | Default branch | Contents |
|---|---|---|---|
| [tl-cloud-infrastructure](https://github.com/TrislabCompany/tl-cloud-infrastructure) | Public | `main` | `README.md` only |
| [tl-platform](https://github.com/TrislabCompany/tl-platform) | Public | `main` | `README.md` only |
| [tl-platform-backstage](https://github.com/TrislabCompany/tl-platform-backstage) | Public | `main` | `README.md` only |

**CLI:**
```bash
for r in tl-cloud-infrastructure tl-platform tl-platform-backstage; do
  gh repo view "TrislabCompany/$r" --json name,visibility,defaultBranchRef,isEmpty
done
```

**Portal (UI):** open each repo URL above and confirm the **Code** tab shows only `README.md` on the `main` branch.

## Step 2 — Add branch protection to `main`

Required on all three repos: a pull request with at least one approval before merging to `main`. This is what the CI/CD design in [governance & identity §2](../spec/03-governance-identity.md#2-identity-model) relies on as the apply gate — deliberately branch protection, not a GitHub Environment, since Environments' required-reviewers feature needs a paid plan once these repos go private and branch protection doesn't, on any visibility.

**CLI** (repeat per repo, substituting `<repo>`):
```bash
gh api repos/TrislabCompany/<repo>/branches/main/protection -X PUT \
  -H "Accept: application/vnd.github+json" \
  -f 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'required_status_checks=null' \
  -F 'enforce_admins=true' \
  -F 'restrictions=null'
```

**Portal (UI):**
1. Repo → **Settings** → **Branches**.
2. **Add branch protection rule** → branch name pattern `main`.
3. Enable **Require a pull request before merging**, **Require approvals** (≥1).
4. (Optional, once `tl-cloud-infrastructure`'s workflows exist) enable **Require status checks to pass** and select the `validate-platform-pull-request` job.
5. Save.

## Note for later (private-repo transition)

While these repos are public, no further setup is needed for cross-repo module reads (`tl-cloud-infrastructure` cloning `tl-platform`) — see [architecture overview §5](../spec/01-architecture-overview.md#module-publishing--consumption). When a repo goes private, add the consumer to `tl-platform`'s **Settings → Actions → General → Access** list. This is a free, repo-level setting — not a paid feature, not a secret to create or rotate.

## Next steps

[01-azure-owner-bootstrap.md](./01-azure-owner-bootstrap.md) — the Azure-side bootstrap.

## Troubleshooting

| Issue | Action |
|---|---|
| `gh api` branch protection call fails with 403 | Confirm your `gh auth` token has `repo` scope and admin rights on the target repo |
| A push to `main` still succeeds without a PR | Confirm `enforce_admins=true` was set — without it, repo admins bypass the rule |
