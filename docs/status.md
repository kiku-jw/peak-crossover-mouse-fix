# Status

## Current

- Repository has been repurposed from the old keyboard workaround to the real CrossOver pointer fix.
- Patched payload files for `CrossOver 25.1.1` are staged under `payload/`.
- App-level patch was already verified locally against `PEAK` and the `EnableMouseInPointer` path.

## Done

- Confirmed the old workaround broke the shape of the repo for the new goal.
- Removed the old BepInEx/menu workaround artifacts from the repo tree.
- Collected the working patched `user32.dll`, `win32u.dll`, and `win32u.so`.
- Added installer and restore scripts with hash validation and automatic backups.
- Added Finder-friendly `.app` wrappers for install and restore.
- Rewrote the README around the real fix and removed the old workaround positioning.
- Completed local smoke tests for install, restore, reinstall, and pointer-test verification.

## In progress

- Preparing the final git commit and GitHub push.

## Next

- Push the rewritten repo to GitHub.
