#!/usr/bin/env bash
set -euo pipefail

BOTTLE="Steam"
CROSSOVER_APP="/Applications/CrossOver.app"
WIDTH=1280
HEIGHT=720
APPLY=0
CLEAR_CACHE=0
FIX_LOCALE=1
FIX_WINDOW=1
FORCE_LOW_DPI=0
FOCUS_WORKAROUND=0
BACKUP_ROOT="${HOME}/Desktop/peak-crossover-backups"

usage() {
  cat <<'EOF'
Usage:
  peak_crossover_fix.sh [options]

What it does:
  - Inspects the CrossOver bottle used by Steam/PEAK
  - Detects the Unity/Wine mouse regression signature in Player.log
  - Optionally applies safe, reversible fixes:
    * force en-US numeric locale inside the bottle
    * force PEAK into 1280x720 windowed mode
    * optionally move the PEAK cache out of the way
    * optionally add Unity boot.config workarounds

Important:
  If the report shows:
    - CrossOver 26.0
    - "EnableMouseInPointer failed"
  then the root cause is very likely the known CrossOver 26.0 Unity input regression.
  In that case this script can clean up the bottle, but the real fix is CrossOver Preview
  or a newer stable build that includes the mouse patch.

Options:
  --apply                 Apply changes. Without this flag the script is read-only.
  --clear-cache           Move LocalLow/LandCrab/PEAK into the backup folder.
  --bottle NAME           CrossOver bottle name. Default: Steam
  --app PATH              CrossOver.app path. Default: /Applications/CrossOver.app
  --width N               Window width for PEAK. Default: 1280
  --height N              Window height for PEAK. Default: 720
  --no-locale             Do not rewrite locale values.
  --no-windowed           Do not rewrite PEAK screen prefs.
  --force-low-dpi         Add forced-low-dpi=1 to boot.config.
  --focus-workaround      Add window-focus-ignore=1 to boot.config.
  --backup-root PATH      Where timestamped backups will be stored.
  --help                  Show this help.

Examples:
  ./peak_crossover_fix.sh
  ./peak_crossover_fix.sh --apply
  ./peak_crossover_fix.sh --apply --clear-cache
  ./peak_crossover_fix.sh --apply --force-low-dpi --focus-workaround
EOF
}

note() {
  printf '%s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -e "$path" ]] || fail "Missing required path: $path"
}

copy_backup() {
  local source="$1"
  local name="$2"

  if [[ -e "$source" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -Rp "$source" "$BACKUP_DIR/$name"
  fi
}

reg_value() {
  local key="$1"
  local value
  value="$(rg -n "^\"${key}\"=" "$USER_REG" | tail -n 1 | sed 's/^[^:]*://; s/^[^=]*=//')"
  printf '%s' "$value"
}

player_log_contains() {
  local pattern="$1"
  [[ -f "$PLAYER_LOG" ]] && rg -q "$pattern" "$PLAYER_LOG"
}

set_boot_flag() {
  local key="$1"
  local value="$2"

  if [[ ! -f "$BOOT_CONFIG" ]]; then
    warn "boot.config not found, skipping $key=$value"
    return
  fi

  if rg -q "^${key}=" "$BOOT_CONFIG"; then
    perl -0pi -e "s/^${key}=.*\$/${key}=${value}/m" "$BOOT_CONFIG"
  else
    printf '%s=%s\n' "$key" "$value" >> "$BOOT_CONFIG"
  fi
}

hex32() {
  printf '%08x' "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      ;;
    --clear-cache)
      CLEAR_CACHE=1
      ;;
    --bottle)
      [[ $# -ge 2 ]] || fail "--bottle requires a value"
      BOTTLE="$2"
      shift
      ;;
    --app)
      [[ $# -ge 2 ]] || fail "--app requires a value"
      CROSSOVER_APP="$2"
      shift
      ;;
    --width)
      [[ $# -ge 2 ]] || fail "--width requires a value"
      WIDTH="$2"
      shift
      ;;
    --height)
      [[ $# -ge 2 ]] || fail "--height requires a value"
      HEIGHT="$2"
      shift
      ;;
    --no-locale)
      FIX_LOCALE=0
      ;;
    --no-windowed)
      FIX_WINDOW=0
      ;;
    --force-low-dpi)
      FORCE_LOW_DPI=1
      ;;
    --focus-workaround)
      FOCUS_WORKAROUND=1
      ;;
    --backup-root)
      [[ $# -ge 2 ]] || fail "--backup-root requires a value"
      BACKUP_ROOT="$2"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

CROSSOVER_BIN="${CROSSOVER_APP}/Contents/SharedSupport/CrossOver/bin"
REGEDIT="${CROSSOVER_BIN}/regedit"
WINESERVER="${CROSSOVER_BIN}/wineserver"
INFO_PLIST="${CROSSOVER_APP}/Contents/Info.plist"
BOTTLE_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}"
STEAM_APPS_DIR="${BOTTLE_DIR}/drive_c/Program Files (x86)/Steam/steamapps"
GAME_DIR="${STEAM_APPS_DIR}/common/PEAK"
USER_REG="${BOTTLE_DIR}/user.reg"
BOOT_CONFIG="${GAME_DIR}/PEAK_Data/boot.config"
CACHE_DIR="${BOTTLE_DIR}/drive_c/users/crossover/AppData/LocalLow/LandCrab/PEAK"
PLAYER_LOG="${CACHE_DIR}/Player.log"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

require_file "$CROSSOVER_APP"
require_file "$REGEDIT"
require_file "$WINESERVER"
require_file "$BOTTLE_DIR"
require_file "$USER_REG"
require_file "$GAME_DIR"

if ! [[ "$WIDTH" =~ ^[0-9]+$ && "$HEIGHT" =~ ^[0-9]+$ ]]; then
  fail "--width and --height must be integers"
fi

CROSSOVER_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null || printf 'unknown')"
CROSSOVER_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || printf 'unknown')"

MOUSE_API_MISSING=0
RENDER_SCALE_COMMA=0
if player_log_contains 'EnableMouseInPointer failed'; then
  MOUSE_API_MISSING=1
fi
if player_log_contains 'Set Render Scale: [0-9],[0-9]'; then
  RENDER_SCALE_COMMA=1
fi

CURRENT_LOCALE_NAME="$(reg_value 'LocaleName' || true)"
CURRENT_DECIMAL="$(reg_value 'sDecimal' || true)"
CURRENT_FULLSCREEN="$(reg_value 'Screenmanager Fullscreen mode_h3630240806' || true)"
CURRENT_WIDTH="$(reg_value 'Screenmanager Resolution Width_h182942802' || true)"
CURRENT_HEIGHT="$(reg_value 'Screenmanager Resolution Height_h2627697771' || true)"

note "PEAK / CrossOver report"
note "  CrossOver version: ${CROSSOVER_VERSION} (${CROSSOVER_BUILD})"
note "  Bottle: ${BOTTLE}"
note "  Game path: ${GAME_DIR}"
note "  Player.log: ${PLAYER_LOG}"
if [[ -f "$PLAYER_LOG" ]]; then
  note "  Log signature: $( [[ "$MOUSE_API_MISSING" -eq 1 ]] && printf 'EnableMouseInPointer failed' || printf 'not found' )"
  note "  Render scale locale issue: $( [[ "$RENDER_SCALE_COMMA" -eq 1 ]] && printf 'comma detected' || printf 'not detected' )"
else
  note "  Log signature: Player.log not found yet"
fi
note "  Registry locale: ${CURRENT_LOCALE_NAME:-unknown} / decimal ${CURRENT_DECIMAL:-unknown}"
note "  Registry screen mode: ${CURRENT_FULLSCREEN:-unknown}, ${CURRENT_WIDTH:-unknown} x ${CURRENT_HEIGHT:-unknown}"

if [[ "$CROSSOVER_VERSION" == "26.0" && "$MOUSE_API_MISSING" -eq 1 ]]; then
  note
  note "Diagnosis:"
  note "  This looks like the known CrossOver 26.0 Unity mouse regression."
  note "  Local config cleanup may help secondary issues, but the missing mouse API itself"
  note "  usually needs CrossOver Preview or a newer stable build."
fi

if [[ "$APPLY" -eq 0 ]]; then
  note
  note "No changes applied."
  note "Run with --apply to write fixes."
  note "Suggested first try: ./peak_crossover_fix.sh --apply --clear-cache"
  exit 0
fi

mkdir -p "$BACKUP_DIR"
copy_backup "$USER_REG" "user.reg"
copy_backup "$BOOT_CONFIG" "boot.config"
if [[ -f "$PLAYER_LOG" ]]; then
  copy_backup "$PLAYER_LOG" "Player.log"
fi

if [[ "$CLEAR_CACHE" -eq 1 && -d "$CACHE_DIR" ]]; then
  note "Moving PEAK cache to backup..."
  mv "$CACHE_DIR" "${BACKUP_DIR}/PEAK-cache"
fi

REG_FILE="$(mktemp "/tmp/peak-fix-${TIMESTAMP}.XXXXXX.reg")"
trap 'rm -f "$REG_FILE"' EXIT

{
  printf 'Windows Registry Editor Version 5.00\n\n'

  if [[ "$FIX_LOCALE" -eq 1 ]]; then
    printf '[HKEY_CURRENT_USER\\Control Panel\\International]\n'
    printf '"Locale"="00000409"\n'
    printf '"LocaleName"="en-US"\n'
    printf '"sDecimal"="."\n'
    printf '"sMonDecimalSep"="."\n'
    printf '"sThousand"=","\n'
    printf '"sMonThousandSep"=","\n'
    printf '"sList"=","\n'
    printf '\n'
  fi

  if [[ "$FIX_WINDOW" -eq 1 ]]; then
    printf '[HKEY_CURRENT_USER\\Software\\LandCrab\\PEAK]\n'
    printf '"Screenmanager Fullscreen mode Default_h401710285"=dword:00000003\n'
    printf '"Screenmanager Fullscreen mode_h3630240806"=dword:00000003\n'
    printf '"Screenmanager Resolution Use Native Default_h1405981789"=dword:00000000\n'
    printf '"Screenmanager Resolution Use Native_h1405027254"=dword:00000000\n'
    printf '"Screenmanager Resolution Width Default_h680557497"=dword:%s\n' "$(hex32 "$WIDTH")"
    printf '"Screenmanager Resolution Width_h182942802"=dword:%s\n' "$(hex32 "$WIDTH")"
    printf '"Screenmanager Resolution Height Default_h1380706816"=dword:%s\n' "$(hex32 "$HEIGHT")"
    printf '"Screenmanager Resolution Height_h2627697771"=dword:%s\n' "$(hex32 "$HEIGHT")"
    printf '"Screenmanager Window Position X_h4088080503"=dword:00000000\n'
    printf '"Screenmanager Window Position Y_h4088080502"=dword:00000000\n'
    printf '"UnitySelectMonitor_h17969598"=dword:00000000\n'
    printf '\n'
  fi
} > "$REG_FILE"

note "Stopping Wine processes for bottle ${BOTTLE}..."
"$WINESERVER" --bottle "$BOTTLE" -k >/dev/null 2>&1 || true

if [[ "$FIX_LOCALE" -eq 1 || "$FIX_WINDOW" -eq 1 ]]; then
  note "Importing registry fixes..."
  "$REGEDIT" --bottle "$BOTTLE" --no-gui "$REG_FILE"
fi

if [[ "$FORCE_LOW_DPI" -eq 1 || "$FOCUS_WORKAROUND" -eq 1 ]]; then
  note "Patching boot.config..."
  if [[ "$FORCE_LOW_DPI" -eq 1 ]]; then
    set_boot_flag "forced-low-dpi" "1"
  fi
  if [[ "$FOCUS_WORKAROUND" -eq 1 ]]; then
    set_boot_flag "window-focus-ignore" "1"
  fi
fi

note
note "Applied fixes."
note "Backups: ${BACKUP_DIR}"
note
note "Next steps:"
note "  1. Launch PEAK once from Steam."
note "  2. Re-run this script without --apply and inspect the report."
note "  3. If Player.log still contains 'EnableMouseInPointer failed' on CrossOver ${CROSSOVER_VERSION},"
note "     move to CrossOver Preview or a newer stable build."
