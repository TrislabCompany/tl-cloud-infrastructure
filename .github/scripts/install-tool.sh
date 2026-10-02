#!/usr/bin/env bash
# Installs a pinned release of a CLI the workflows use, after checking its
# SHA-256 against the release's checksum file (08 section 3, Tool versions).
#
#   install-tool.sh conftest|trivy|actionlint <version>
set -euo pipefail
tool=$1 version=$2
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
  *) echo "unknown tool: $tool" >&2; exit 2 ;;
esac
dir="$RUNNER_TEMP/tools/$tool"
mkdir -p "$dir"
cd "$dir"
curl -fsSL -o "$asset" "$base/$asset"
curl -fsSL -o sums.txt "$base/$sums"
grep " $asset\$" sums.txt | sha256sum -c -
tar -xzf "$asset" "$tool"
echo "$dir" >> "$GITHUB_PATH"
