#!/usr/bin/env python3
"""Check the action pins: every `uses:` in .github/workflows/ and .github/actions/
names an action or a reusable workflow by its full 40-character commit SHA, with
the version in a comment (`uses: actions/checkout@<sha> # v7.0.1`), as
.claude/rules/workflows.md says.

Needs no pin: a local action (`uses: ./...`), and this repository's own reusable
workflows (`<this repository>/.github/workflows/<file>@main`), which are its own
reviewed code. A `docker://` image needs a digest (`@sha256:...`).

Run from the repository root: python3 <this file>. Exits 1 on an unpinned use."""

import os
import pathlib
import re
import subprocess
import sys

ROOT = next(d for d in pathlib.Path(__file__).resolve().parents if (d / ".github").is_dir())
USES = re.compile(r"^\s*(?:-\s+)?uses:\s*['\"]?([^'\"\s#]+)['\"]?\s*(#.*)?$")
SHA = re.compile(r"@[0-9a-f]{40}$")


def this_repository():
    """owner/name, from GitHub Actions or else from the origin remote."""
    if os.environ.get("GITHUB_REPOSITORY"):
        return os.environ["GITHUB_REPOSITORY"].lower()
    url = subprocess.run(
        ["git", "-C", str(ROOT), "remote", "get-url", "origin"], capture_output=True, text=True, check=False
    ).stdout.strip()
    match = re.search(r"[:/]([^/:]+/[^/]+?)(?:\.git)?$", url)
    return match.group(1).lower() if match else ""


def problem(ref, comment, own):
    if ref.startswith("./"):
        return None
    if own and ref.lower().startswith(f"{own}/.github/workflows/"):
        return None
    if ref.startswith("docker://"):
        return None if "@sha256:" in ref else "a docker:// image without a digest"
    if not SHA.search(ref):
        return "not pinned by a full commit SHA"
    if not comment or not re.search(r"v?\d+(\.\d+)*", comment):
        return "pinned by SHA without the version in a comment"
    return None


def main():
    own = this_repository()
    errors = []
    files = sorted(
        p
        for folder in ("workflows", "actions")
        for p in (ROOT / ".github" / folder).rglob("*")
        if p.suffix in (".yml", ".yaml")
    )
    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            match = USES.match(line)
            if match and (why := problem(match.group(1), match.group(2), own)):
                errors.append(f"{path.relative_to(ROOT).as_posix()}:{number}: {match.group(1)} is {why}")

    for error in errors:
        print(f"::error::{error}")
    print(f"{len(files)} workflow files, {len(errors)} unpinned uses")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
