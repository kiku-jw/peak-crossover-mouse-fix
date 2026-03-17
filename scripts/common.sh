#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CROSSOVER_APP_PATH="${CROSSOVER_APP_PATH:-/Applications/CrossOver.app}"
WINE_ROOT="$CROSSOVER_APP_PATH/Contents/SharedSupport/CrossOver/lib/wine"
STATE_ROOT="${STATE_ROOT:-$HOME/Library/Application Support/PEAK-CrossOver-Mouse-Fix}"
BACKUP_ROOT="$STATE_ROOT/backups"
PAYLOAD_ROOT=""
PAYLOAD_VERSION=""

TARGET_USER32="$WINE_ROOT/x86_64-windows/user32.dll"
TARGET_WIN32U_DLL="$WINE_ROOT/x86_64-windows/win32u.dll"
TARGET_WIN32U_SO="$WINE_ROOT/x86_64-unix/win32u.so"

PAYLOAD_USER32=""
PAYLOAD_WIN32U_DLL=""
PAYLOAD_WIN32U_SO=""

STOCK_USER32_SHA=""
STOCK_WIN32U_DLL_SHA=""
STOCK_WIN32U_SO_SHA=""

PATCHED_USER32_SHA=""
PATCHED_WIN32U_DLL_SHA=""
PATCHED_WIN32U_SO_SHA=""

print_header() {
  echo
  echo "== $1 =="
}

hash_file() {
  /usr/bin/shasum -a 256 "$1" | awk '{print $1}'
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}

set_profile() {
  case "$1" in
    25.1.1)
      PAYLOAD_VERSION="25.1.1"
      PAYLOAD_ROOT="$REPO_ROOT/payload/crossover-25.1.1"
      STOCK_USER32_SHA="6511e0d8cc2994c0cd45483fe3d619eead11fde49b7c658a6b369a0585d94d8e"
      STOCK_WIN32U_DLL_SHA="e37bcdf0c384a22a67989cbaf2f461d8ed7190190d3b32da7de16829f74d524f"
      STOCK_WIN32U_SO_SHA="690cb360ca3c71a92f71e00e7b725d9b49bad086596343d77e6f3c4c8728a5b5"
      PATCHED_USER32_SHA="92808f4914134442a7f26c6f80ae55e0149e8ad357370f92ab6a805f394fa3c4"
      PATCHED_WIN32U_DLL_SHA="40b306e0a05ff287b5ef180495e36a5a8f3cf3ed7691014b7e401e269d4a3b5e"
      PATCHED_WIN32U_SO_SHA="7aa1ec59987047845acb7e22125c4daa77b00a7c48181caf1d07ee55ecd9c0bc"
      ;;
    26.0)
      PAYLOAD_VERSION="26.0"
      PAYLOAD_ROOT="$REPO_ROOT/payload/crossover-26.0"
      STOCK_USER32_SHA="58e85f07eed228c03797a81eb43dcc3b1844fa74e189c8c6a8ca89d5b8100557"
      STOCK_WIN32U_DLL_SHA="9d9660edcb93e32fccc887dfde4336c99034008ce1f764cd2bde7ebe3b541a84"
      STOCK_WIN32U_SO_SHA="b1bcda93d3e79bc54e6ffbebc75eff67ba1c31df52be77bfb10dcda31d77cb65"
      PATCHED_USER32_SHA="15b85af5ea2e35b61c7cb71133f1ba307b8672a02cc7e4d9cf674fcc11d1b537"
      PATCHED_WIN32U_DLL_SHA="6e902be7d005b11c9dff33d097e89bad6e42c4066a9bddbf03a9142240d8f218"
      PATCHED_WIN32U_SO_SHA="99686643355671a41b20dc796511702410ebcae2b56b0ab7482742e441f598b1"
      ;;
    *)
      return 1
      ;;
  esac

  PAYLOAD_USER32="$PAYLOAD_ROOT/x86_64-windows/user32.dll"
  PAYLOAD_WIN32U_DLL="$PAYLOAD_ROOT/x86_64-windows/win32u.dll"
  PAYLOAD_WIN32U_SO="$PAYLOAD_ROOT/x86_64-unix/win32u.so"
}

resolve_profile() {
  local version
  version="$(crossover_version)"

  case "$version" in
    25.1.1)
      set_profile "25.1.1"
      ;;
    26.0|26.0.*)
      set_profile "26.0"
      ;;
    *)
      echo "Unsupported CrossOver version: $version" >&2
      return 1
      ;;
  esac
}

ensure_layout() {
  resolve_profile
  require_file "$TARGET_USER32"
  require_file "$TARGET_WIN32U_DLL"
  require_file "$TARGET_WIN32U_SO"
  require_file "$PAYLOAD_USER32"
  require_file "$PAYLOAD_WIN32U_DLL"
  require_file "$PAYLOAD_WIN32U_SO"
  mkdir -p "$BACKUP_ROOT"
}

current_user32_sha() {
  hash_file "$TARGET_USER32"
}

current_win32u_dll_sha() {
  hash_file "$TARGET_WIN32U_DLL"
}

current_win32u_so_sha() {
  hash_file "$TARGET_WIN32U_SO"
}

current_state() {
  local user32_sha win32u_dll_sha win32u_so_sha
  resolve_profile
  user32_sha="$(current_user32_sha)"
  win32u_dll_sha="$(current_win32u_dll_sha)"
  win32u_so_sha="$(current_win32u_so_sha)"

  if [[ "$user32_sha" == "$PATCHED_USER32_SHA" && "$win32u_dll_sha" == "$PATCHED_WIN32U_DLL_SHA" && "$win32u_so_sha" == "$PATCHED_WIN32U_SO_SHA" ]]; then
    echo "patched"
    return
  fi

  if [[ "$user32_sha" == "$STOCK_USER32_SHA" && "$win32u_dll_sha" == "$STOCK_WIN32U_DLL_SHA" && "$win32u_so_sha" == "$STOCK_WIN32U_SO_SHA" ]]; then
    echo "stock"
    return
  fi

  echo "custom"
}

print_hash_report() {
  cat <<EOF
user32.dll  : $(current_user32_sha)
win32u.dll  : $(current_win32u_dll_sha)
win32u.so   : $(current_win32u_so_sha)
EOF
}

crossover_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CROSSOVER_APP_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown"
}

make_backup_dir() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="$BACKUP_ROOT/$ts"
  mkdir -p "$backup_dir/x86_64-windows" "$backup_dir/x86_64-unix"
  echo "$backup_dir"
}

backup_targets() {
  local backup_dir="$1"
  cp -f "$TARGET_USER32" "$backup_dir/x86_64-windows/"
  cp -f "$TARGET_WIN32U_DLL" "$backup_dir/x86_64-windows/"
  cp -f "$TARGET_WIN32U_SO" "$backup_dir/x86_64-unix/"
}

install_payload() {
  cp -f "$PAYLOAD_USER32" "$TARGET_USER32"
  cp -f "$PAYLOAD_WIN32U_DLL" "$TARGET_WIN32U_DLL"
  cp -f "$PAYLOAD_WIN32U_SO" "$TARGET_WIN32U_SO"
}

verify_patched() {
  [[ "$(current_user32_sha)" == "$PATCHED_USER32_SHA" ]]
  [[ "$(current_win32u_dll_sha)" == "$PATCHED_WIN32U_DLL_SHA" ]]
  [[ "$(current_win32u_so_sha)" == "$PATCHED_WIN32U_SO_SHA" ]]
}

latest_backup_dir() {
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1
}

restore_from_backup_dir() {
  local backup_dir="$1"
  require_file "$backup_dir/x86_64-windows/user32.dll"
  require_file "$backup_dir/x86_64-windows/win32u.dll"
  require_file "$backup_dir/x86_64-unix/win32u.so"

  cp -f "$backup_dir/x86_64-windows/user32.dll" "$TARGET_USER32"
  cp -f "$backup_dir/x86_64-windows/win32u.dll" "$TARGET_WIN32U_DLL"
  cp -f "$backup_dir/x86_64-unix/win32u.so" "$TARGET_WIN32U_SO"
}
