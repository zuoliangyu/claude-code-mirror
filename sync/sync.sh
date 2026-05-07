#!/usr/bin/env bash
#
# sync.sh — mirror Claude Code release artifacts from downloads.claude.ai
# to the local working dir, ready for `gh release create` upload.
#
# Inputs (env):
#   CHANNEL          latest | stable     (default: latest)
#   WORK_DIR         where to stage      (default: ./work)
#   PLATFORMS        space-separated     (default: all 8)
#
# Outputs:
#   $WORK_DIR/$VERSION/manifest.json
#   $WORK_DIR/$VERSION/{platform}-{binary}     (asset names flat for GH Release)
#   $WORK_DIR/$VERSION/SHA256SUMS
#   stdout: VERSION=...
#
# Exits non-zero on any failure (set -e). Designed to be called from the
# GitHub Actions sync workflow which then handles release creation.

set -euo pipefail

CHANNEL="${CHANNEL:-latest}"
WORK_DIR="${WORK_DIR:-./work}"
UPSTREAM="https://downloads.claude.ai/claude-code-releases"

ALL_PLATFORMS=(
  "darwin-arm64"
  "darwin-x64"
  "linux-arm64"
  "linux-x64"
  "linux-arm64-musl"
  "linux-x64-musl"
  "win32-x64"
  "win32-arm64"
)
PLATFORMS_STR="${PLATFORMS:-${ALL_PLATFORMS[*]}}"
read -ra PLATFORMS_ARR <<< "$PLATFORMS_STR"

log() { echo "[sync] $*" >&2; }

VERSION=$(curl -fsSL --retry 3 "$UPSTREAM/$CHANNEL")
if [[ -z "$VERSION" ]]; then
  log "failed to fetch $CHANNEL version"
  exit 1
fi
log "channel=$CHANNEL version=$VERSION"

OUT="$WORK_DIR/$VERSION"
mkdir -p "$OUT"

# 1. Manifest
log "downloading manifest.json"
curl -fsSL --retry 3 "$UPSTREAM/$VERSION/manifest.json" -o "$OUT/manifest.json"

# Validate manifest is JSON and contains version field
if ! jq -e '.version' "$OUT/manifest.json" >/dev/null; then
  log "manifest.json is invalid"
  exit 1
fi

MANIFEST_VERSION=$(jq -r '.version' "$OUT/manifest.json")
if [[ "$MANIFEST_VERSION" != "$VERSION" ]]; then
  log "manifest version mismatch: file=$MANIFEST_VERSION endpoint=$VERSION"
  exit 1
fi

# 2. Each platform binary
SUMS_FILE="$OUT/SHA256SUMS"
: > "$SUMS_FILE"

for plat in "${PLATFORMS_ARR[@]}"; do
  log "platform: $plat"
  binary_name=$(jq -r --arg p "$plat" '.platforms[$p].binary // empty' "$OUT/manifest.json")
  expected=$(jq -r --arg p "$plat" '.platforms[$p].checksum // empty' "$OUT/manifest.json")
  if [[ -z "$binary_name" || -z "$expected" ]]; then
    log "  manifest missing entry for $plat — skipping"
    continue
  fi

  # Asset name on GH Release is "{platform}-{binary}" so it's flat & unambiguous.
  asset_name="${plat}-${binary_name}"
  out_path="$OUT/$asset_name"

  log "  downloading $binary_name → $asset_name"
  curl -fsSL --retry 3 "$UPSTREAM/$VERSION/$plat/$binary_name" -o "$out_path"

  actual=$(sha256sum "$out_path" | cut -d' ' -f1)
  if [[ "$actual" != "$expected" ]]; then
    log "  CHECKSUM MISMATCH for $plat: expected=$expected actual=$actual"
    exit 1
  fi
  log "  ✓ checksum ok ($expected)"
  echo "$actual  $asset_name" >> "$SUMS_FILE"
done

log "complete: $OUT"
echo "VERSION=$VERSION"
