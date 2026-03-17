# PEAK Mouse Not Working in CrossOver on macOS: Real Unity Pointer Fix

This repository fixes the real `PEAK` mouse bug in `CrossOver` on `macOS` by patching the CrossOver Wine layer that breaks Unity pointer input.

It is for people searching things like:

- `PEAK mouse not working CrossOver`
- `PEAK left click not working macOS`
- `PEAK right click not working CrossOver`
- `PEAK menu not clickable CrossOver`
- `Unity 6 EnableMouseInPointer failed`
- `CrossOver mouse buttons not working in PEAK`

This is not the old keyboard rebind workaround. That path was removed from this repo because it was a gameplay workaround and could interfere with normal online play. This repo now ships the real pointer fix instead.

## What this fixes

Use this if all or most of these are true:

- the mouse cursor moves in `PEAK`
- the menu does not react to hover or click
- left click or right click does nothing in-game
- camera look may still work
- `Player.log` contains `EnableMouseInPointer failed with the following error: Call not implemented.`

After a successful install, a fresh `Player.log` should no longer contain that line.

## What this repo patches

The installer replaces these three CrossOver app-level files:

- `user32.dll`
- `win32u.dll`
- `win32u.so`

Those are the pieces that control the broken `EnableMouseInPointer` path used by newer Unity builds.

The repo includes:

- a one-shot installer script
- a restore script with automatic backups
- Finder-friendly `.app` wrappers for install and restore
- prebuilt payload files for `CrossOver 25.1.1`
- the source patch diff used for the fix

## Supported target

This repo is currently packaged for:

- `PEAK`
- `CrossOver 25.1.1`
- `macOS`
- `Unity 6`

The installer validates the exact stock hashes before replacing anything. If your CrossOver files are different, the installer stops instead of overwriting unknown binaries.

## Quick start

1. Download or clone this repository.
2. Keep the `.app` bundles inside the repo folder.
3. Double-click [Install PEAK CrossOver Mouse Fix.app](apps/Install%20PEAK%20CrossOver%20Mouse%20Fix.app).
4. Let the Terminal installer finish.
5. Fully quit `CrossOver` and `Steam`.
6. Start `Steam` again.
7. Launch `PEAK` with `DirectX 11` or add the launch option:

```text
-force-d3d11
```

## Command-line install

If you prefer Terminal:

```bash
bash scripts/install-crossover-pointer-fix.sh
```

To restore the latest backup:

```bash
bash scripts/restore-crossover-pointer-fix.sh --latest
```

## Backup and restore

Before patching, the installer creates a backup in:

```text
~/Library/Application Support/PEAK-CrossOver-Mouse-Fix/backups/<timestamp>
```

To restore with Finder, double-click [Restore PEAK CrossOver Mouse Fix.app](apps/Restore%20PEAK%20CrossOver%20Mouse%20Fix.app).

## How to verify the fix

Launch `PEAK`, then inspect:

```text
~/Library/Application Support/CrossOver/Bottles/Steam/drive_c/users/crossover/AppData/LocalLow/LandCrab/PEAK/Player.log
```

You want to see:

- `Forcing GfxDevice: Direct3D 11`
- `Input initialized.`

You do not want to see:

- `EnableMouseInPointer failed with the following error: Call not implemented.`

## Why this works

The underlying problem is a missing or stubbed `EnableMouseInPointer` path in Wine/CrossOver for the newer Unity input stack used by `PEAK`.

This repo applies the actual pointer-layer fix instead of:

- remapping mouse buttons to keys
- injecting BepInEx menu hacks
- modifying gameplay behavior
- patching game files in ways that can affect multiplayer behavior

## Repo layout

- [scripts/install-crossover-pointer-fix.sh](scripts/install-crossover-pointer-fix.sh) - install the supported payload with backup
- [scripts/restore-crossover-pointer-fix.sh](scripts/restore-crossover-pointer-fix.sh) - restore the latest or chosen backup
- [apps/Install PEAK CrossOver Mouse Fix.app](apps/Install%20PEAK%20CrossOver%20Mouse%20Fix.app) - Finder launcher for install
- [apps/Restore PEAK CrossOver Mouse Fix.app](apps/Restore%20PEAK%20CrossOver%20Mouse%20Fix.app) - Finder launcher for restore
- [patches/unity-enable-mouse-in-pointer.patch](patches/unity-enable-mouse-in-pointer.patch) - source-level patch diff
- [payload/crossover-25.1.1](payload/crossover-25.1.1) - supported prebuilt payload files

## Troubleshooting

### Installer says the current files are unsupported

Your CrossOver build is not the exact stock layout this repo expects. Do not force it. Wait for a matching package or rebuild the payload for your version.

### PEAK still does not react to clicks

Make sure you are launching the DirectX 11 path:

- choose `DirectX 11` if Steam prompts you
- or set `-force-d3d11`

Then check `Player.log` again.

### CrossOver was updated after installing

CrossOver updates can replace the patched files. Run the installer again, or restore first and then install the matching package for the new version.

## Safety notes

- This repo patches `CrossOver.app`, not just one bottle.
- The installer makes backups automatically.
- The installer refuses unknown app-level hashes.
- The game stays vanilla; this is not a gameplay mod.

## Licensing

- Repo scripts and docs: MIT
- Patched Wine-derived payload details: see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

## Not affiliated

This repository is unofficial and is not affiliated with:

- `PEAK`
- `Landfall`
- `Aggro Crab`
- `CodeWeavers`
- `CrossOver`
