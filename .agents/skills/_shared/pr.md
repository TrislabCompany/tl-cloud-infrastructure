# Shared steps of the infrastructure skills

Every skill in `.agents/skills/` runs these steps around its own. A skill's own file says what it reads, computes and writes. This file says how it starts, checks and ends. The rules are in [AGENTS.md](../../../AGENTS.md).

The commands are PowerShell one-liners, as in the runbooks. Run from the root of `tl-cloud-infrastructure`. `$repo` is `TrislabCompany/tl-cloud-infrastructure`.

## 1. Preflight

Stop with the reason when one fails.

1. **The user's own sign-in:**
   - `gh auth status` shows a signed-in account.
   - `gh api repos/TrislabCompany/tl-cloud-infrastructure --jq .permissions.push` is `true`: the user can push a branch.
   - `az account show --query user.name -o tsv` shows a user. `az` is needed only by the skills that read Azure; they say so.
   - Use these sign-ins as they are. Never ask for or store a token, and never sign in as a service principal.
2. **A clean start:**
   - `git status --porcelain` is empty. Otherwise ask the user to commit or stash first.
   - `git fetch origin --prune`.
   - `git switch -c <branch> origin/main`. Each skill names its branch.
3. **Open PRs that touch the same files:** `gh pr list -R $repo --state open --json number,title,headRefName,files --jq '.[] | select(any(.files[]; .path | test("<paths>"))) | "\(.number) \(.title)"'`.
   - When one changes the same catalog entry or folder, show it and ask whether to go on.
   - When this change needs another PR applied first, note its number for `Depends on #<n>`.
4. **Tools:**
   - `tofu`, `python` (or `python3`) with PyYAML, and `pwsh` for stamps.
   - `conftest` is optional: without it, say that the catalog rules run in the PR's plan.

## 2. Show, then ask

Before writing anything, show:
- the computed values: names, codes, ranges, dates;
- every file that will change, and how;
- the PR title and the roots it will plan, in apply order;
- any `Depends on #<n>`, and the steps that come after the PR.

**Ask for a yes.** Without one, delete the branch (`git switch - && git branch -D <branch>`) and stop.

## 3. Write

- Edit YAML by hand-sized edits that keep the file's comments, order and style. Never re-serialise a whole catalog file with a YAML library: the comments would be lost.
- New entries go at the end of their list unless the file orders them otherwise.
- Use LF line endings.

## 4. Check

Run the checks that are installed, and show their result:

```powershell
tofu fmt -check -recursive
python .agents/skills/_shared/check-catalog.py        # exit 2: conftest is missing, the plan runs it
tofu -chdir=<root> init -backend=false; tofu -chdir=<root> validate   # each changed .tf root, then remove <root>/.terraform
```

- A rule that fails: fix the file, or stop and explain it. Never weaken a rule in `policy/` to pass.
- Before the commit, `git status --porcelain` must list only the files from step 2.
- Before every push, the first one and any after a rebase, `git diff --stat origin/main...HEAD` must list only the files from step 2. A file outside that list is a stop: find out which commit brings it.

## Update a PR

- To take `main`'s changes, `git fetch origin; git rebase origin/main`, then the diff check above, then `git push --force-with-lease`.
- When part of a PR moves to another PR, rebuild the branch instead of adding a commit that takes the part out: `git switch -C <branch> origin/main; git checkout <old head> -- <this PR's files>`, then commit. Once the other PR is merged, a commit that took its files out undoes it on `main`, and the next `/apply` destroys what it created.

## 5. Commit, push, open the PR

```powershell
git add <files>; git commit -m "<title>"; git push -u origin <branch>
gh pr create -R TrislabCompany/tl-cloud-infrastructure --base main --head <branch> --title "<title>" --body-file <body.md>
```

The title is a plain sentence with the lifecycle verb, such as "Create the landing zone products-prod-neu". No AI attribution in the commit or the PR (AGENTS.md).

The body, written to a temporary file outside the repository:

```markdown
<what changes and why, one paragraph>

**Files:** <list>
**Roots, in apply order:** <list, with their Environments>
**After the apply:** <what exists then, and the next PR if any>
**Expected re-runs:** <only when known, for example the budget's 401 on a new subscription>

Depends on #<n>          <- only when there is one, as the last line
```

## 6. Stop at the PR

The skill ends here. Print:
- the PR's URL;
- the next steps for the reviewers:
  1. Wait for the plan and the checks: `gh pr checks <n> -R TrislabCompany/tl-cloud-infrastructure --watch`.
  2. Read the plan comment of every root the PR plans, not only the one it is about. A plan that creates or destroys more than expected, or plans a root the PR shouldn't touch, is a stop.
  3. A `devops` member other than the author approves the PR.
  4. A writer comments `/apply`.
  5. A `devops` member other than that commenter approves each Environment's run.
  6. The workflow merges the PR when `applied` is green.
- any manual step the skill names, such as the state lock of a cancel.

Never approve, comment `/apply`, approve a run or merge. Then `git switch -` back to the branch the user was on.
