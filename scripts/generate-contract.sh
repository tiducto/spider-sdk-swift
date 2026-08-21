#!/usr/bin/env bash
# Regenerate the routing wire models + persisted-query ids + contract version from the published contract.
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

# Persisted-query ids (x-persisted-query-id per routing operation). The gateway 403s an id it hasn't
# registered, so these must never be hand-edited out of step with the spec.
node - "$WORK_DIR/openapi.json" "$SDK_DIR/PersistedQueries.swift" <<'NODE'
const fs = require('fs');
const [specPath, outPath] = process.argv.slice(2);
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const ops = [];
for (const [route, methods] of Object.entries(spec.paths || {})) {
    for (const op of Object.values(methods)) {
        const id = op && op['x-persisted-query-id'];
        if (!id) continue;
        const path = route.replace(/^\/routing\//, '');
        ops.push({ name: path.replace(/[^A-Za-z0-9]/g, ''), id, path });
    }
}
if (ops.length === 0) {
    console.error('ERROR: no x-persisted-query-id found in the routing spec');
    process.exit(1);
}
ops.sort((a, b) => a.name.localeCompare(b.name));
const consts = ops
    .map((o) => `    static let ${o.name} = PersistedOp(id: "${o.id}", path: "${o.path}")`)
    .join('\n');
fs.writeFileSync(outPath, `// Generated from the published contract's x-persisted-query-id by scripts/generate-contract.sh. Do not edit.
//
// The gateway enforces a persisted-query allowlist: clients POST { id, variables } and the id is the
// lowercase-hex SHA-256 of the canonical query text. An id the gateway has not registered is rejected 403,
// so these must never drift from the published contract — they are generated, never hand-typed.

struct PersistedOp {
    let id: String
    let path: String
}

enum PersistedQueries {
${consts}
}
`);
process.stdout.write(String(ops.length));
NODE
echo " persisted-query ids written"

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
