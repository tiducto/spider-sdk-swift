#!/usr/bin/env bash
# Stamp the package version (contract.patch from version.properties) into Sources/SpiderSDK/SDKVersion.swift.
# The full semver goes into the `x-spider-sdk` identity header on every request, so it must be readable at
# runtime. Mirrors spider-sdk-typescript/scripts/stamp-version.mjs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$(grep '^contract=' "$REPO_ROOT/version.properties" | cut -d= -f2 | tr -d '[:space:]')"
patch="$(grep '^patch=' "$REPO_ROOT/version.properties" | cut -d= -f2 | tr -d '[:space:]')"
version="${contract}.${patch}"

printf '// Stamped from version.properties (contract.patch) by scripts/stamp-version.sh at release. Do not edit by hand.\nlet SDK_VERSION = "%s"\n' "$version" \
    > "$REPO_ROOT/Sources/SpiderSDK/SDKVersion.swift"
echo "stamped SDK_VERSION = $version"
