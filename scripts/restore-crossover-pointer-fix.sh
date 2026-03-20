#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

print_header "Restore CrossOver Mouse Fix Backup"
echo "CrossOver app: $CROSSOVER_APP_PATH"
echo "CrossOver version: $(crossover_version)"

ensure_layout
echo "Supported payload: CrossOver $PAYLOAD_VERSION"
echo "Target user32: $TARGET_USER32"
echo "Target win32u.dll: $TARGET_WIN32U_DLL"
echo "Target win32u.so: $TARGET_WIN32U_SO"

backup_dir=""
if [[ "${1:-}" == "--latest" || $# -eq 0 ]]; then
  backup_dir="$(latest_backup_dir)"
else
  backup_dir="$1"
fi

if [[ -z "$backup_dir" || ! -d "$backup_dir" ]]; then
  echo
  echo "No backup directory found."
  echo "Expected one under: $BACKUP_ROOT"
  exit 1
fi

restore_from_backup_dir "$backup_dir"

cat <<EOF

Restore complete.

Restored from:
$backup_dir

Current hashes:
$(print_hash_report)
EOF
