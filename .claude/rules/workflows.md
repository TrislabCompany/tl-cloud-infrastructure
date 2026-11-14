---
paths:
  - ".github/**"
---

# GitHub Actions workflows and scripts

Checked by: `actionlint` and `.github/scripts/check-pins.py` (`pull-request-plan.yml`, when `.github/` changes). A workflow change goes in its own PR: a PR that touches `.github/**` together with a root fails (AGENTS.md).

## Workflows

- **`permissions: {}` at the top,** and each job grants only what it needs. `id-token: write` only in the job that signs in, with the layer's identity, in the layer's Environment.
- **Every action is pinned by its full commit SHA,** with the version in a comment: `uses: actions/checkout@<sha> # v7.0.1`. Tools by version, installed with `.github/scripts/install-tool.sh`, which checks the checksum.
- `actions/checkout` with `persist-credentials: false`, unless a later step pushes.
- **Never put `${{ … }}` of untrusted input** (a PR title, a branch name, a comment body) straight into `run:`. Pass it through `env:` and quote it: `"$BODY"`.
- A file starts with a comment saying what it does, when it runs and which spec section it implements. A summary job that is a required check passes when there is nothing to check.
- A `concurrency` group per PR, with `cancel-in-progress: true` for plans and `false` for applies.

## Logging in a run

The run's log, its step summary and the PR comment are what someone reads when an apply fails at night. Make them short and specific:

- `::error::<what failed>. <what to do>` for a failure, one per problem, then exit non-zero after reporting them all. `::notice::` for a skipped or noteworthy step. `::group::<root>` around each root's output.
- The plan goes to the PR as a comment, and a summary to `$GITHUB_STEP_SUMMARY`.
- **Never print a secret,** a token, a state file or `az` output that may contain one; mask a value derived from a secret with `::add-mask::`. `tofu plan` output is sensitive-aware: never print `-json` plans in full.

## Scripts

`.github/scripts/*.sh`: `#!/usr/bin/env bash` and `set -euo pipefail`, every variable quoted, a header comment with what it does and who calls it.
