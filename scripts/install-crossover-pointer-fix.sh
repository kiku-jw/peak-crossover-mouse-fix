#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

print_header "PEAK CrossOver Mouse Fix Installer"
echo "CrossOver app: $CROSSOVER_APP_PATH"
echo "CrossOver version: $(crossover_version)"

ensure_layout
echo "Supported payload: CrossOver $PAYLOAD_VERSION"

state="$(current_state)"
case "$state" in
  patched)
    echo
    echo "The supported patched files are already installed."
    echo "Detected payload: CrossOver $PAYLOAD_VERSION"
    print_hash_report
    exit 0
    ;;
  stock)
    ;;
  custom)
    echo
    echo "Unsupported or already customized CrossOver files detected."
    echo "Refusing to overwrite unknown binaries."
    print_hash_report
    exit 1
    ;;
esac

backup_dir="$(make_backup_dir)"
backup_targets "$backup_dir"
install_payload

if ! verify_patched; then
  echo
  echo "Patch copy finished, but the final hashes do not match the expected payload."
  echo "Rollback from: $backup_dir"
  exit 1
fi

cat <<EOF

Install complete.

Backup:
$backup_dir

Next steps:
1. Fully quit CrossOver and Steam.
2. Start Steam again.
3. Launch PEAK with DirectX 11 or set the launch option to -force-d3d11.
4. Verify Player.log no longer contains:
   EnableMouseInPointer failed with the following error: Call not implemented.
EOF
