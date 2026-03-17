# Plan

## Goal

Replace the old keyboard workaround repo with a real CrossOver mouse fix for `PEAK` on macOS.

## Scope

1. Ship a reproducible installer that patches CrossOver app-level `user32/win32u`.
2. Ship a restore path with automatic backups.
3. Package double-clickable macOS `.app` wrappers for install and restore.
4. Rewrite the repository docs around the real root fix and deprecate the old workaround approach.
5. Publish the updated repo so users can find and apply the fix quickly.

## Non-goals

- Rebuild Wine from source inside this repo.
- Maintain compatibility with arbitrary CrossOver versions without hash validation.
- Keep the old BepInEx keyboard workaround as the default path.

## Milestones

### 1. Repository reset

- Remove the keyboard workaround payload and scripts.
- Add execution docs and repo structure for the new fix.

Done when:
- old workaround files are removed from the root path
- new structure exists for `apps/`, `scripts/`, `payload/`, and `patches/`

### 2. Installer and restore flow

- Add shared shell logic for hash checks, backups, install, and restore.
- Validate supported stock hashes and patched hashes for `CrossOver 25.1.1`.

Done when:
- installer refuses unknown/custom app-level binaries
- restore can put back the latest backup

### 3. Finder-friendly packaging

- Add minimal `.app` bundles that open the install or restore script in Terminal.

Done when:
- both `.app` bundles exist in the repo
- their launchers are executable

### 4. Public docs and SEO rewrite

- Rewrite `README.md` around the real fix.
- Explain why the old keyboard workaround was dropped.
- Add search-friendly wording for the PEAK/CrossOver/Unity mouse bug.

Done when:
- README first screen clearly explains the real fix and quick start
- README includes verify, restore, safety, and compatibility notes

### 5. Verification and publish

- Smoke-test install detection logic locally.
- Confirm the patched app-level files expose `EnableMouseInPointer`.
- Commit and push to GitHub.

Done when:
- local tests pass
- repo is committed and pushed to `main`
