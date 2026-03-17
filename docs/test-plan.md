# Test Plan

## Local validation

### 1. Git and file layout

Command:

```bash
git status --short
find apps payload scripts patches docs -maxdepth 3 | sort
```

Pass when:
- repo tree matches the new structure
- no unexpected generated junk is staged

### 2. Installer hash detection

Command:

```bash
bash scripts/install-crossover-pointer-fix.sh
```

Pass when:
- installer either reports `already installed` or installs successfully
- backup directory is printed
- patched hashes verify cleanly

### 3. Restore path

Command:

```bash
bash scripts/restore-crossover-pointer-fix.sh --latest
```

Pass when:
- latest backup restores without path errors
- stock hashes are back in place

### 4. Reinstall after restore

Command:

```bash
bash scripts/install-crossover-pointer-fix.sh
```

Pass when:
- patched hashes are restored
- installer remains idempotent

### 5. Pointer smoke test

Command:

```bash
"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine" \
  --bottle Steam \
  'Z:\private\tmp\cx-pointer-test\pointer-test.exe'
```

Pass when:
- output contains `EnableMouseInPointer(true) => ret=1 err=Success.`

### 6. PEAK runtime confirmation

Command:

```bash
rg -n 'EnableMouseInPointer failed|Call not implemented|Input initialized' \
  "$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/users/crossover/AppData/LocalLow/LandCrab/PEAK/Player.log"
```

Pass when:
- `Input initialized` is present
- `Call not implemented` is absent after a fresh run

## Publish validation

### 7. README and SEO checks

Command:

```bash
sed -n '1,220p' README.md
```

Pass when:
- the first screen explains the real fix, not the old keyboard workaround
- quick start, restore, compatibility, and troubleshooting are present

### 8. Push readiness

Command:

```bash
git diff --stat
git status
```

Pass when:
- only intended repo changes remain
- branch is ready for commit and push
