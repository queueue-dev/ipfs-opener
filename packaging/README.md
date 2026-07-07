# Packaging assets

Drop the DMG installer assets here. `scripts/build_release.sh` picks them up
automatically.

| File | What it is | Notes |
|------|-----------|-------|
| `dmg-background.png` | Installer window background | Provide at **2× the window point size** in pixels for a crisp Retina result (e.g. a 600×400-pt window → 1200×800-px image). PNG. |
| `VolumeIcon.icns` | The mounted disk image's icon (shows on the desktop / Finder sidebar) | If you only have a 1024×1024 PNG, drop it as `volumeicon_1024.png` instead and it'll be converted to `.icns`. |

Nothing else in this folder is required. These assets are optional — the build
still produces a plain DMG without them.
