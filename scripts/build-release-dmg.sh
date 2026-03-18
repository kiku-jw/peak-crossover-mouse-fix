#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-v2.1.1}"
PRODUCT_NAME="PEAK CrossOver Mouse Fix"
DMG_BASENAME="PEAK-CrossOver-Mouse-Fix-${VERSION}"
DIST_DIR="$REPO_ROOT/dist"
DMG_PATH="$DIST_DIR/${DMG_BASENAME}.dmg"
TMP_ROOT="$(mktemp -d /private/tmp/peak-crossover-mouse-fix.XXXXXX)"
STAGE_DIR="$TMP_ROOT/${DMG_BASENAME}"
TMP_DMG="$TMP_ROOT/${DMG_BASENAME}.dmg"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR"
mkdir -p "$STAGE_DIR"

cp -R "$REPO_ROOT/apps/Install PEAK CrossOver Mouse Fix.app" "$STAGE_DIR/"
cp -R "$REPO_ROOT/apps/Restore PEAK CrossOver Mouse Fix.app" "$STAGE_DIR/"

embed_support() {
  local app_dir="$1"
  local support_dir="$app_dir/Contents/Resources/Support"
  mkdir -p "$support_dir/scripts"
  cp -f "$REPO_ROOT/scripts/common.sh" "$support_dir/scripts/"
  cp -f "$REPO_ROOT/scripts/install-crossover-pointer-fix.sh" "$support_dir/scripts/"
  cp -f "$REPO_ROOT/scripts/restore-crossover-pointer-fix.sh" "$support_dir/scripts/"
  cp -R "$REPO_ROOT/payload" "$support_dir/"
  cp -R "$REPO_ROOT/patches" "$support_dir/"
  cp -R "$REPO_ROOT/LICENSES" "$support_dir/"
  cp -f "$REPO_ROOT/THIRD_PARTY_NOTICES.md" "$support_dir/"
}

embed_support "$STAGE_DIR/Install PEAK CrossOver Mouse Fix.app"
embed_support "$STAGE_DIR/Restore PEAK CrossOver Mouse Fix.app"
cp -f "$REPO_ROOT/README.md" "$STAGE_DIR/"

cat > "$STAGE_DIR/Install PEAK CrossOver Mouse Fix.command" <<'EOF'
#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/Install PEAK CrossOver Mouse Fix.app/Contents/MacOS/install-peak-crossover-mouse-fix"
EOF

cat > "$STAGE_DIR/Restore PEAK CrossOver Mouse Fix.command" <<'EOF'
#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/Restore PEAK CrossOver Mouse Fix.app/Contents/MacOS/restore-peak-crossover-mouse-fix"
EOF

find "$STAGE_DIR" -name '.DS_Store' -delete
find "$STAGE_DIR" -name '._*' -delete
chmod +x "$STAGE_DIR/Install PEAK CrossOver Mouse Fix.app/Contents/MacOS/install-peak-crossover-mouse-fix"
chmod +x "$STAGE_DIR/Restore PEAK CrossOver Mouse Fix.app/Contents/MacOS/restore-peak-crossover-mouse-fix"
chmod +x "$STAGE_DIR/Install PEAK CrossOver Mouse Fix.command"
chmod +x "$STAGE_DIR/Restore PEAK CrossOver Mouse Fix.command"

hdiutil create -volname "$PRODUCT_NAME" -srcfolder "$STAGE_DIR" -format UDZO "$TMP_DMG" >/dev/null
cp -f "$TMP_DMG" "$DMG_PATH"

echo "$DMG_PATH"
