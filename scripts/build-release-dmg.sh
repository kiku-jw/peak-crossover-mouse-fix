#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-v2.1.0}"
PRODUCT_NAME="PEAK CrossOver Mouse Fix"
DMG_BASENAME="PEAK-CrossOver-Mouse-Fix-${VERSION}"
DIST_DIR="$REPO_ROOT/dist"
DMG_PATH="$DIST_DIR/${DMG_BASENAME}.dmg"
TMP_ROOT="$(mktemp -d /private/tmp/peak-crossover-mouse-fix.XXXXXX)"
STAGE_DIR="$TMP_ROOT/${DMG_BASENAME}"
SUPPORT_DIR="$STAGE_DIR/Support"
TMP_DMG="$TMP_ROOT/${DMG_BASENAME}.dmg"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR"
mkdir -p "$SUPPORT_DIR"

cp -R "$REPO_ROOT/apps/Install PEAK CrossOver Mouse Fix.app" "$STAGE_DIR/"
cp -R "$REPO_ROOT/apps/Restore PEAK CrossOver Mouse Fix.app" "$STAGE_DIR/"
mkdir -p "$SUPPORT_DIR/scripts"
cp -f "$REPO_ROOT/scripts/common.sh" "$SUPPORT_DIR/scripts/"
cp -f "$REPO_ROOT/scripts/install-crossover-pointer-fix.sh" "$SUPPORT_DIR/scripts/"
cp -f "$REPO_ROOT/scripts/restore-crossover-pointer-fix.sh" "$SUPPORT_DIR/scripts/"
cp -R "$REPO_ROOT/payload" "$SUPPORT_DIR/"
cp -R "$REPO_ROOT/patches" "$SUPPORT_DIR/"
cp -R "$REPO_ROOT/LICENSES" "$SUPPORT_DIR/"
cp -f "$REPO_ROOT/THIRD_PARTY_NOTICES.md" "$SUPPORT_DIR/"
cp -f "$REPO_ROOT/README.md" "$STAGE_DIR/"

find "$STAGE_DIR" -name '.DS_Store' -delete
find "$STAGE_DIR" -name '._*' -delete
chmod +x "$STAGE_DIR/Install PEAK CrossOver Mouse Fix.app/Contents/MacOS/install-peak-crossover-mouse-fix"
chmod +x "$STAGE_DIR/Restore PEAK CrossOver Mouse Fix.app/Contents/MacOS/restore-peak-crossover-mouse-fix"

hdiutil create -volname "$PRODUCT_NAME" -srcfolder "$STAGE_DIR" -format UDZO "$TMP_DMG" >/dev/null
cp -f "$TMP_DMG" "$DMG_PATH"

echo "$DMG_PATH"
