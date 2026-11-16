#!/usr/bin/env bash
# Installs a pinned release of a CLI the workflows use, after checking its
# SHA-256 against the release's checksum file (08 section 3, Tool versions).
#
#   install-tool.sh conftest|trivy|actionlint|ruff <version>
set -euo pipefail
tool=$1 version=$2
# The binary's path inside the archive, and how many leading folders to strip.
member=$tool strip=0
case "$tool" in
  conftest)
    base="https://github.com/open-policy-agent/conftest/releases/download/v$version"
    asset="conftest_${version}_Linux_x86_64.tar.gz" sums=checksums.txt ;;
  trivy)
    base="https://github.com/aquasecurity/trivy/releases/download/v$version"
    asset="trivy_${version}_Linux-64bit.tar.gz" sums="trivy_${version}_checksums.txt" ;;
  actionlint)
    base="https://github.com/rhysd/actionlint/releases/download/v$version"
    asset="actionlint_${version}_linux_amd64.tar.gz" sums="actionlint_${version}_checksums.txt" ;;
  ruff)
    base="https://github.com/astral-sh/ruff/releases/download/$version"
    asset="ruff-x86_64-unknown-linux-gnu.tar.gz" sums=sha256.sum
    member="ruff-x86_64-unknown-linux-gnu/ruff" strip=1 ;;
  *) echo "unknown tool: $tool" >&2; exit 2 ;;
esac
dir="$RUNNER_TEMP/tools/$tool"
mkdir -p "$dir"
cd "$dir"
# GitHub's release downloads fail now and then with a 403 or 5xx that passes
# on a retry a few seconds later; one failed download used to fail the whole
# plan or apply (tl-cloud-infrastructure#131).
fetch() {
  curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 --retry-max-time 120 -o "$1" "$2" || {
    echo "::error::download of $2 failed after 5 retries. Re-run the failed jobs."
    exit 1
  }
}
fetch "$asset" "$base/$asset"
fetch sums.txt "$base/$sums"
# A checksum line is "<sha256>  <asset>", or "<sha256> *<asset>" in binary mode.
grep -E "[ *]$asset\$" sums.txt | sha256sum -c -
tar -xzf "$asset" --strip-components="$strip" "$member"
echo "$dir" >> "$GITHUB_PATH"
