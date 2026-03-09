#!/usr/bin/env bash
set -euo pipefail

BOTTLE="Steam"
CROSSOVER_APP="/Applications/CrossOver.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/PeakMenuKeyboard.cs"
OUT_DIR="${SCRIPT_DIR}/dist"
OUT_DLL="${OUT_DIR}/PeakMenuKeyboard.dll"
GAME_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}/drive_c/Program Files (x86)/Steam/steamapps/common/PEAK"
INSTALL=0

usage() {
  cat <<'EOF'
Usage:
  build_peak_menu_keyboard.sh [options]

What it does:
  - Builds the Peak Menu Keyboard BepInEx plugin using CrossOver's C# compiler
  - Optionally installs the built DLL into PEAK/BepInEx/plugins

Options:
  --install             Copy the built DLL into the game's plugins folder
  --bottle NAME         CrossOver bottle name. Default: Steam
  --app PATH            CrossOver.app path. Default: /Applications/CrossOver.app
  --help                Show this help
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL=1
      ;;
    --bottle)
      [[ $# -ge 2 ]] || fail "--bottle requires a value"
      BOTTLE="$2"
      GAME_DIR="${HOME}/Library/Application Support/CrossOver/Bottles/${BOTTLE}/drive_c/Program Files (x86)/Steam/steamapps/common/PEAK"
      shift
      ;;
    --app)
      [[ $# -ge 2 ]] || fail "--app requires a value"
      CROSSOVER_APP="$2"
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

CX_WINE="${CROSSOVER_APP}/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"
CSC_EXE="${CROSSOVER_APP}/Contents/SharedSupport/CrossOver/share/wine/mono/wine-mono-10.4.1/lib/mono/4.5/csc.exe"
BEPINEX_DLL="${GAME_DIR}/BepInEx/core/BepInEx.dll"
HARMONY_DLL="${GAME_DIR}/BepInEx/core/0Harmony.dll"
UNITY_DLL="${GAME_DIR}/PEAK_Data/Managed/UnityEngine.dll"
UNITY_CORE_DLL="${GAME_DIR}/PEAK_Data/Managed/UnityEngine.CoreModule.dll"
UNITY_UIMODULE_DLL="${GAME_DIR}/PEAK_Data/Managed/UnityEngine.UIModule.dll"
UNITY_UI_DLL="${GAME_DIR}/PEAK_Data/Managed/UnityEngine.UI.dll"
UNITY_INPUT_DLL="${GAME_DIR}/PEAK_Data/Managed/Unity.InputSystem.dll"
UNITY_INPUT_LEGACY_DLL="${GAME_DIR}/PEAK_Data/Managed/UnityEngine.InputLegacyModule.dll"
NETSTANDARD_DLL="${GAME_DIR}/PEAK_Data/Managed/netstandard.dll"

[[ -x "$CX_WINE" ]] || fail "CrossOver wine launcher not found: $CX_WINE"
[[ -f "$CSC_EXE" ]] || fail "C# compiler not found: $CSC_EXE"
[[ -f "$SRC" ]] || fail "Source file not found: $SRC"
[[ -f "$BEPINEX_DLL" ]] || fail "BepInEx.dll not found: $BEPINEX_DLL"
[[ -f "$HARMONY_DLL" ]] || fail "0Harmony.dll not found: $HARMONY_DLL"
[[ -f "$UNITY_DLL" ]] || fail "UnityEngine.dll not found: $UNITY_DLL"
[[ -f "$UNITY_CORE_DLL" ]] || fail "UnityEngine.CoreModule.dll not found: $UNITY_CORE_DLL"
[[ -f "$UNITY_UIMODULE_DLL" ]] || fail "UnityEngine.UIModule.dll not found: $UNITY_UIMODULE_DLL"
[[ -f "$UNITY_UI_DLL" ]] || fail "UnityEngine.UI.dll not found: $UNITY_UI_DLL"
[[ -f "$UNITY_INPUT_DLL" ]] || fail "Unity.InputSystem.dll not found: $UNITY_INPUT_DLL"
[[ -f "$UNITY_INPUT_LEGACY_DLL" ]] || fail "UnityEngine.InputLegacyModule.dll not found: $UNITY_INPUT_LEGACY_DLL"
[[ -f "$NETSTANDARD_DLL" ]] || fail "netstandard.dll not found: $NETSTANDARD_DLL"

mkdir -p "$OUT_DIR"

win_path() {
  local unix_path="$1"
  printf 'Z:%s' "$(printf '%s' "$unix_path" | sed 's#/#\\\\#g')"
}

note "Building Peak Menu Keyboard plugin with wine-mono csc..."
"$CX_WINE" --bottle "$BOTTLE" "$(win_path "$CSC_EXE")" \
  /nologo \
  /target:library \
  /optimize+ \
  "/out:$(win_path "$OUT_DLL")" \
  "/reference:$(win_path "$BEPINEX_DLL")" \
  "/reference:$(win_path "$HARMONY_DLL")" \
  "/reference:$(win_path "$UNITY_DLL")" \
  "/reference:$(win_path "$UNITY_CORE_DLL")" \
  "/reference:$(win_path "$UNITY_UIMODULE_DLL")" \
  "/reference:$(win_path "$UNITY_UI_DLL")" \
  "/reference:$(win_path "$UNITY_INPUT_DLL")" \
  "/reference:$(win_path "$UNITY_INPUT_LEGACY_DLL")" \
  "/reference:$(win_path "$NETSTANDARD_DLL")" \
  "$(win_path "$SRC")"

note "Built: $OUT_DLL"

if [[ "$INSTALL" -eq 1 ]]; then
  mkdir -p "$GAME_DIR/BepInEx/plugins"
  cp "$OUT_DLL" "$GAME_DIR/BepInEx/plugins/PeakMenuKeyboard.dll"
  note "Installed: $GAME_DIR/BepInEx/plugins/PeakMenuKeyboard.dll"
fi
