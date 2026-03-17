# Third-Party Notices

This repository contains helper scripts written for this project under the MIT license.

It also includes prebuilt patched Wine-derived runtime files for:

- `user32.dll`
- `win32u.dll`
- `win32u.so`

These payload files were produced from Wine-based sources and are distributed separately from the MIT-licensed repo scripts.

## Upstream base

- Project: Wine
- Website: https://www.winehq.org/
- Source: https://gitlab.winehq.org/wine/wine
- Relevant patch: [patches/unity-enable-mouse-in-pointer.patch](patches/unity-enable-mouse-in-pointer.patch)

## Important note

The payload in this repo is intended for the specific supported CrossOver build documented in the README.

If your CrossOver version differs, do not force-install these files without checking compatibility first.
