# PEAK Mouse Not Working in CrossOver on macOS: Left Click, Right Click, and Menu Fix

This repository is a practical workaround for the `PEAK` mouse bug in `CrossOver` on `macOS`, especially when the game cursor moves but the UI does not react to hover or click, and the left mouse button does nothing in-game.

It is aimed at searches like:

- `PEAK mouse not working CrossOver`
- `PEAK left click not working macOS`
- `PEAK menu not clickable CrossOver`
- `EnableMouseInPointer failed PEAK`
- `Unity 6 mouse bug CrossOver macOS`

## What this fixes

This workaround is for the specific situation where:

- the mouse cursor moves in `PEAK`
- menu buttons do not highlight
- menu buttons do not click
- in-game camera look may still work
- left click does nothing in gameplay
- `Player.log` contains `EnableMouseInPointer failed with the following error: Call not implemented.`

## What this repo does

The main install script:

- installs `BepInEx` for `PEAK`
- installs `PEAK Unbound`
- writes the required `winhttp` Wine DLL overrides
- forces an `en_US` locale in the bottle environment
- remaps broken mouse actions to keyboard keys
- installs a bundled `PeakMenuKeyboard.dll` plugin that tries to bypass the broken menu by auto-invoking PEAK menu actions

## Current keybind workaround

- `F` = primary action / left mouse button
- `G` = secondary action / right mouse button
- `Enter` = menu click / submit
- `E` = interact / also confirm in some menus
- `Q` = drop
- `X` = scroll backward

## Tested target

This was built around the problem case:

- `PEAK`
- `CrossOver 26.0`
- `macOS`
- `Unity 6`
- broken mouse path with `EnableMouseInPointer failed`

It may also help on nearby CrossOver/Wine builds with the same symptom pattern.

## Quick start

1. Clone this repository.
2. Open Terminal in the repo folder.
3. Run:

```bash
chmod +x peak_install_keyboard_workaround.sh
./peak_install_keyboard_workaround.sh
```

4. Fully restart `Steam` and `PEAK`.
5. Wait 10 to 15 seconds on the main menu.
6. If the menu is still stubborn, try:

- `F6` to force `Play Solo`
- `F5` to force `Play` / continue
- `Enter` to submit

## Manual scripts

### `peak_install_keyboard_workaround.sh`

The main one-shot installer. This is what most people should run.

It:

- installs `BepInEx`
- installs `PEAK Unbound`
- installs the bundled `PeakMenuKeyboard.dll`
- writes `HKCU\Software\Wine\DllOverrides\winhttp = native,builtin`
- writes `HKCU\Software\Wine\AppDefaults\PEAK.exe\DllOverrides\winhttp = native,builtin`
- writes keyboard remaps for `PEAK`

### `peak_crossover_fix.sh`

Bottle triage and cleanup helper. Useful if you want to:

- inspect the bottle
- force `PEAK` into windowed mode
- reset locale values
- clear the `LocalLow/LandCrab/PEAK` cache

### `build_peak_menu_keyboard.sh`

Rebuilds the bundled menu plugin from source with CrossOver's wine-mono C# compiler.

```bash
chmod +x build_peak_menu_keyboard.sh
./build_peak_menu_keyboard.sh --install
```

## Files in this repo

- `peak_install_keyboard_workaround.sh` - one-shot workaround installer
- `peak_crossover_fix.sh` - bottle cleanup and diagnostic helper
- `PeakMenuKeyboard.cs` - source for the menu auto-start / menu bypass plugin
- `build_peak_menu_keyboard.sh` - rebuild script for the menu plugin
- `dist/PeakMenuKeyboard.dll` - prebuilt plugin binary

## How the menu workaround works

The bundled `PeakMenuKeyboard` plugin does two things:

1. It provides keyboard-driven fallback behavior for broken UI situations.
2. It patches PEAK menu entry points directly and attempts to call real menu methods such as:

- `MainMenu.PlaySoloClicked`
- `MainMenuMainPage.PlayClicked`
- `MainMenuPlayPage.PlayClicked`

That matters because some PEAK menus are not plain Unity buttons anymore, so generic UI navigation alone is not enough.

## Troubleshooting

### Check whether BepInEx loaded

After launching `PEAK`, inspect:

`BepInEx/LogOutput.log`

You want to see lines like:

- `Loading [Peak Menu Keyboard ...]`
- `Plugin PeakUnbound is loaded!`

### Check whether the underlying bug is still there

Inspect:

`AppData/LocalLow/LandCrab/PEAK/Player.log`

If you still see:

`EnableMouseInPointer failed with the following error: Call not implemented.`

that usually means the upstream CrossOver/Unity mouse path is still broken, and this repo is acting as a workaround, not a real root fix.

### If the main menu still will not move

Try this exact sequence:

1. Close `Steam` and `PEAK`.
2. Launch again.
3. Wait 10 to 15 seconds on the menu.
4. Press `F6`.
5. If needed, press `F5`.
6. Use `Enter` to submit and `F` / `G` in gameplay.

## Known limitation

This does not repair the upstream mouse bug inside CrossOver/Wine. It works around it.

If a newer `CrossOver Preview` or stable build fixes the underlying Unity mouse regression, that is the cleaner long-term answer.

## Not affiliated

This repository is unofficial and is not affiliated with:

- `PEAK`
- `Aggro Crab`
- `Landfall`
- `CodeWeavers`
- `CrossOver`

## License

MIT

## Search keywords

PEAK mouse not working, PEAK left click not working, PEAK right click not working, PEAK menu not clickable, PEAK CrossOver fix, CrossOver 26 mouse bug, Unity 6 EnableMouseInPointer failed, PEAK macOS workaround, Wine mouse bug PEAK, BepInEx PEAK fix.
