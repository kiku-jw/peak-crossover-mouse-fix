#!/usr/bin/env bash
set -euo pipefail

BOTTLE="Steam"
APP_ID="3527290"
CROSSOVER_APP="/Applications/CrossOver.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOTTLE_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}"
USER_REG="${BOTTLE_DIR}/user.reg"
CX_WINE="${CROSSOVER_APP}/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"
GAME_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}/drive_c/Program Files (x86)/Steam/steamapps/common/PEAK"
CXBOTTLE_CONF="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}/cxbottle.conf"
BACKUP_ROOT="${HOME}/Desktop/peak-keyboard-workaround-backups"
PRIMARY_KEY="<Keyboard>/f"
TMP_DIR="$(mktemp -d "/tmp/peak-workaround.XXXXXX")"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

BEPINEX_URL="https://gcdn.thunderstore.io/live/repository/packages/BepInEx-BepInExPack_PEAK-5.4.2403.zip"
UNBOUND_URL="https://gcdn.thunderstore.io/live/repository/packages/glarmer-PEAK_Unbound-2.1.0.zip"
MENU_PLUGIN_DLL="${SCRIPT_DIR}/dist/PeakMenuKeyboard.dll"

usage() {
  cat <<'EOF'
Usage:
  peak_install_keyboard_workaround.sh [options]

What it does:
  - Installs BepInEx for PEAK
  - Installs PEAK Unbound
  - Installs the Peak Menu Keyboard auto-start plugin if bundled with this repo
  - Rebinds PEAK's UsePrimary action from mouse-left to keyboard F
  - Rebinds PEAK's UseSecondary action from mouse-right to keyboard G
  - Rebinds menu/UI click to Enter while keeping mouse cursor movement
  - Writes Wine DLL overrides for winhttp in the bottle registry
  - Adds Wine environment variables in cxbottle.conf:
      WINEDLLOVERRIDES=winhttp=n,b
      LANG=en_US.UTF-8
      LC_ALL=en_US.UTF-8
      LANGUAGE=en_US:en

Why:
  This is a workaround for the CrossOver 26.0 Unity mouse regression.
  It does not truly fix broken mouse UI input. It makes PEAK playable
  from keyboard while waiting for a CrossOver build with the upstream fix.
  If the bundled menu plugin is present, it also tries to bypass the
  broken main menu by auto-invoking PEAK menu actions on launch.

Options:
  --bottle NAME         CrossOver bottle name. Default: Steam
  --game-dir PATH       Override PEAK install directory
  --app PATH            Override CrossOver.app path
  --primary-key PATH    InputSystem binding path for UsePrimary. Default: <Keyboard>/f
  --backup-root PATH    Backup destination root
  --help                Show this help

Menu controls to try after install:
  - Navigate: W/A/S/D or Arrow keys
  - Confirm: Enter or E
  - Back: Escape

Gameplay after install:
  - Primary action: F
  - Secondary action: G
  - Menu click: Enter
  - Interact: E
  - Drop: Q
EOF
}

note() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bottle)
      [[ $# -ge 2 ]] || fail "--bottle requires a value"
      BOTTLE="$2"
      BOTTLE_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}"
      USER_REG="${BOTTLE_DIR}/user.reg"
      GAME_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}/drive_c/Program Files (x86)/Steam/steamapps/common/PEAK"
      CXBOTTLE_CONF="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}/cxbottle.conf"
      shift
      ;;
    --game-dir)
      [[ $# -ge 2 ]] || fail "--game-dir requires a value"
      GAME_DIR="$2"
      shift
      ;;
    --app)
      [[ $# -ge 2 ]] || fail "--app requires a value"
      CROSSOVER_APP="$2"
      shift
      ;;
    --primary-key)
      [[ $# -ge 2 ]] || fail "--primary-key requires a value"
      PRIMARY_KEY="$2"
      shift
      ;;
    --backup-root)
      [[ $# -ge 2 ]] || fail "--backup-root requires a value"
      BACKUP_ROOT="$2"
      BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
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

[[ -d "$GAME_DIR" ]] || fail "PEAK directory not found: $GAME_DIR"
[[ -f "$CXBOTTLE_CONF" ]] || fail "Bottle config not found: $CXBOTTLE_CONF"
[[ -d "$CROSSOVER_APP" ]] || fail "CrossOver.app not found: $CROSSOVER_APP"
[[ -f "$USER_REG" ]] || fail "Bottle registry not found: $USER_REG"
[[ -x "$CX_WINE" ]] || fail "CrossOver wine launcher not found: $CX_WINE"

mkdir -p "$BACKUP_DIR"

backup_if_exists() {
  local source="$1"
  local name="$2"
  if [[ -e "$source" ]]; then
    cp -Rp "$source" "$BACKUP_DIR/$name"
  fi
}

note "Backing up current state..."
backup_if_exists "$CXBOTTLE_CONF" "cxbottle.conf"
backup_if_exists "$USER_REG" "user.reg"
backup_if_exists "$GAME_DIR/winhttp.dll" "winhttp.dll"
backup_if_exists "$GAME_DIR/doorstop_config.ini" "doorstop_config.ini"
backup_if_exists "$GAME_DIR/.doorstop_version" ".doorstop_version"
backup_if_exists "$GAME_DIR/BepInEx" "BepInEx"
backup_if_exists "$GAME_DIR/BepInEx/plugins/PeakMenuKeyboard.dll" "PeakMenuKeyboard.dll"

note "Downloading BepInEx pack and PEAK Unbound..."
curl -L "$BEPINEX_URL" -o "$TMP_DIR/bepinex.zip"
curl -L "$UNBOUND_URL" -o "$TMP_DIR/unbound.zip"

mkdir -p "$TMP_DIR/bepinex" "$TMP_DIR/unbound"
unzip -q "$TMP_DIR/bepinex.zip" -d "$TMP_DIR/bepinex"
unzip -q "$TMP_DIR/unbound.zip" -d "$TMP_DIR/unbound"

note "Installing BepInEx files into PEAK..."
cp -R "$TMP_DIR/bepinex/BepInExPack_PEAK/." "$GAME_DIR/"
mkdir -p "$GAME_DIR/BepInEx/plugins" "$GAME_DIR/BepInEx/config"
cp "$TMP_DIR/unbound/PEAKUnbound.dll" "$GAME_DIR/BepInEx/plugins/PEAKUnbound.dll"

if [[ -f "$MENU_PLUGIN_DLL" ]]; then
  note "Installing bundled Peak Menu Keyboard plugin..."
  cp "$MENU_PLUGIN_DLL" "$GAME_DIR/BepInEx/plugins/PeakMenuKeyboard.dll"
else
  note "Bundled Peak Menu Keyboard plugin not found, skipping it."
fi

note "Writing PEAK Unbound config..."
cat > "$GAME_DIR/BepInEx/config/PEAKUnbound.cfg" <<EOF
## Settings file was created manually for the CrossOver keyboard workaround.
## PEAK Unbound will keep filling defaults around this on next launch.

[Mouse]
## Replace broken mouse-left primary action with a keyboard fallback.
# Setting type: String
# Default value: <Mouse>/leftButton
UsePrimary; leftButton = ${PRIMARY_KEY}

## Replace broken mouse-right secondary action with a keyboard fallback.
# Setting type: String
# Default value: <Mouse>/rightButton
UseSecondary; rightButton = <Keyboard>/g

## Keep aiming with the mouse, but send the UI click from the keyboard.
# Setting type: String
# Default value: <Mouse>/leftButton
Click; leftButton = <Keyboard>/enter

## Avoid conflicting with the new secondary action on G.
# Setting type: String
# Default value: <Keyboard>/g
ScrollBackward; g = <Keyboard>/x
EOF

note "Patching bottle environment variables..."
python3 - "$CXBOTTLE_CONF" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
lines = text.splitlines()
updates = {
    "WINEDLLOVERRIDES": "winhttp=n,b",
    "LANG": "en_US.UTF-8",
    "LC_ALL": "en_US.UTF-8",
    "LANGUAGE": "en_US:en",
}

start = None
end = None
for i, line in enumerate(lines):
    if line.strip() == "[EnvironmentVariables]":
        start = i
        end = len(lines)
        for j in range(i + 1, len(lines)):
            if lines[j].startswith("[") and lines[j].endswith("]"):
                end = j
                break
        break

if start is None:
    lines.extend(["", "[EnvironmentVariables]"])
    start = len(lines) - 1
    end = len(lines)

section = lines[start + 1:end]

def render(key: str, value: str) -> str:
    return f'"{key}" = "{value}"'

for key, value in updates.items():
    replaced = False
    for idx, line in enumerate(section):
        stripped = line.strip()
        if stripped.startswith(f'"{key}" ='):
            section[idx] = render(key, value)
            replaced = True
            break
    if not replaced:
        section.append(render(key, value))

lines[start + 1:end] = section
path.write_text("\n".join(lines) + "\n")
PY

note "Writing Wine registry DLL overrides..."
"$CX_WINE" --bottle "$BOTTLE" reg add 'HKCU\Software\Wine\DllOverrides' /v winhttp /t REG_SZ /d 'native,builtin' /f >/dev/null
"$CX_WINE" --bottle "$BOTTLE" reg add 'HKCU\Software\Wine\AppDefaults\PEAK.exe\DllOverrides' /v winhttp /t REG_SZ /d 'native,builtin' /f >/dev/null

note
note "Installed workaround."
note "Backups: $BACKUP_DIR"
note
note "What changed:"
note "  - BepInEx installed into PEAK"
note "  - PEAK Unbound installed"
if [[ -f "$MENU_PLUGIN_DLL" ]]; then
  note "  - Peak Menu Keyboard plugin installed"
fi
note "  - UsePrimary remapped to ${PRIMARY_KEY}"
note "  - UseSecondary remapped to <Keyboard>/g"
note "  - UI Click remapped to <Keyboard>/enter"
note "  - ScrollBackward moved from G to X to avoid a conflict"
note "  - Wine registry now forces native winhttp for PEAK.exe"
note "  - Bottle env updated for winhttp + en_US locale"
note
note "Try this in the menu:"
note "  - Move the cursor with the mouse"
note "  - Press Enter to click"
note "  - W/A/S/D or Arrow keys may also navigate some menus"
note "  - Enter or E may also confirm selected buttons"
note "  - F6 may force Play Solo on stubborn menus"
note "  - F5 may force Play/Continue on stubborn menus"
note "  - Escape to go back"
note
note "Try this in-game:"
note "  - F for the primary action"
note "  - G for the secondary action"
note "  - X for scroll backward"
note "  - E to interact"
note
note "Verification after launch:"
note "  - Check BepInEx/LogOutput.log exists"
note "  - Check it contains: Plugin PeakUnbound is loaded!"
