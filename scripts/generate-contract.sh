#!/usr/bin/env bash
# Regenerate the routing wire models + contract version from the published contract.
#
# The generated Swift is committed on purpose: the package carries the types, not the spec, and there is no
# codegen step in the SDK's own build. Types come from spider-codegen (tiducto/spider-codegen) — our own
# generator — NOT any third-party OpenAPI generator. Mirrors spider-sdk-{kotlin,typescript}/scripts/generate-contract.sh.
#
# Usage:
#   scripts/generate-contract.sh                      # fetch main from the contract repo
#   scripts/generate-contract.sh --ref v5.0           # a specific ref/tag/branch
#   scripts/generate-contract.sh --spec path/to.json  # a local routing-openapi.json, no fetch
#
# CONTRACT_REPO_TOKEN reads the private contract + codegen repos (CI); locally falls back to ambient `gh` auth.
# CODEGEN_REF pins the spider-codegen ref (default below); CODEGEN_DIR points at a local checkout to skip the clone.
set -euo pipefail

CONTRACT_REPO="${CONTRACT_REPO:-tiducto/spider-contract}"
CONTRACT_REF="main"
CODEGEN_REPO="${CODEGEN_REPO:-tiducto/spider-codegen}"
CODEGEN_REF="${CODEGEN_REF:-master}"
LOCAL_SPEC=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref) CONTRACT_REF="$2"; shift 2 ;;
        --spec) LOCAL_SPEC="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTING_DIR="$REPO_ROOT/Sources/SpiderContract/Routing"
SDK_DIR="$REPO_ROOT/Sources/SpiderSDK"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ -n "$LOCAL_SPEC" ]]; then
    echo "==> Using local spec: $LOCAL_SPEC"
    cp "$LOCAL_SPEC" "$WORK_DIR/openapi.json"
else
    echo "==> Fetching dist/routing-openapi.json from $CONTRACT_REPO@$CONTRACT_REF"
    GH_TOKEN="${CONTRACT_REPO_TOKEN:-${GH_TOKEN:-}}" \
        gh api "repos/$CONTRACT_REPO/contents/dist/routing-openapi.json?ref=$CONTRACT_REF" --jq '.content' \
        | base64 -d > "$WORK_DIR/openapi.json"
fi

# Contract (major.minor) version this SDK speaks — the spec's info.version. Package version is separate
# (version.properties, applied by scripts/stamp-version.sh).
CONTRACT_VERSION="$(node -e "process.stdout.write(String(require('$WORK_DIR/openapi.json').info.version))")"
echo "==> Contract version: $CONTRACT_VERSION"
printf '// Generated from the published contract'"'"'s info.version by scripts/generate-contract.sh. Do not edit by hand.\nlet CONTRACT_VERSION = "%s"\n' "$CONTRACT_VERSION" > "$SDK_DIR/ContractVersion.swift"

# Obtain + build the generator. Set CODEGEN_DIR to a local checkout to skip the clone (local dev).
if [[ -n "${CODEGEN_DIR:-}" ]]; then
    echo "==> Using local spider-codegen at $CODEGEN_DIR"
    CODEGEN="$CODEGEN_DIR"
else
    echo "==> Cloning $CODEGEN_REPO@$CODEGEN_REF"
    CODEGEN="$WORK_DIR/spider-codegen"
    GH_TOKEN="${CONTRACT_REPO_TOKEN:-${GH_TOKEN:-}}" \
        gh repo clone "$CODEGEN_REPO" "$CODEGEN" -- --depth 1 --branch "$CODEGEN_REF" \
        || { echo "ERROR: could not clone $CODEGEN_REPO@$CODEGEN_REF — CONTRACT_REPO_TOKEN needs read access to $CODEGEN_REPO." >&2; exit 1; }
fi

echo "==> Building spider-codegen"
( cd "$CODEGEN" && npm ci --silent && npm run build --silent )

echo "==> Generating Swift wire models with spider-codegen"
node "$CODEGEN/dist/cli.js" \
    --spec "$WORK_DIR/openapi.json" \
    --lang swift \
    --out "$WORK_DIR/gen" \
    --optional-lists nullable \
    --visibility public

if ! ls "$WORK_DIR"/gen/*.swift >/dev/null 2>&1; then
    echo "ERROR: generator produced no Swift models at $WORK_DIR/gen" >&2
    exit 1
fi

echo "==> Syncing into $ROUTING_DIR (replacing existing)"
rm -rf "$ROUTING_DIR"
mkdir -p "$ROUTING_DIR"
cp "$WORK_DIR"/gen/*.swift "$ROUTING_DIR/"

echo "==> Done. $(ls "$ROUTING_DIR"/*.swift | wc -l | tr -d ' ') model files."
echo "    The stops + realtime wire types are hand-written (Sources/SpiderSDK/{Stops,Realtime}.swift), not generated."
