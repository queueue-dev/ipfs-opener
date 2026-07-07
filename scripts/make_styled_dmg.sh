#!/bin/bash
#
# make_styled_dmg.sh — Build a styled DMG (background art, icons, fixed window,
# custom volume icon) from a built .app.
#
# Usage: make_styled_dmg.sh <path-to-.app> <output.dmg>
#
# Layout is derived from packaging/installer_background.png (a 2160×1320 asset).
# Override the on-screen window width (points) with WIN_W; icon size scales with
# it to stay matched to the arrow in the art (override with ICON_SIZE).
#
set -euo pipefail

APP_SRC="${1:?usage: make_styled_dmg.sh <app> <output.dmg>}"
OUT_DMG="${2:?usage: make_styled_dmg.sh <app> <output.dmg>}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOLNAME="IPFS Opener"
APP_IN_DMG="IPFS Opener.app"
BG_SRC="${BG_SRC:-$ROOT/packaging/installer_background.png}"
VOLICON="$ROOT/packaging/VolumeIcon.icns"

ART_W=2160; ART_H=1320
WIN_W="${WIN_W:-648}"
WIN_H=$(awk "BEGIN{printf \"%d\", $WIN_W*$ART_H/$ART_W + 0.5}")
DPI=$(awk "BEGIN{printf \"%g\", $ART_W*72/$WIN_W}")
ICON_SIZE="${ICON_SIZE:-$(awk "BEGIN{printf \"%d\", 128*$WIN_W/1080 + 0.5}")}"
# Icon centers, scaled from the art (app at px 560,664; Applications at 1600,664).
APP_X=$(awk "BEGIN{printf \"%d\", 560*$WIN_W/$ART_W + 0.5}")
APP_Y=$(awk "BEGIN{printf \"%d\", 664*$WIN_W/$ART_W + 0.5}")
APPS_X=$(awk "BEGIN{printf \"%d\", 1600*$WIN_W/$ART_W + 0.5}")
APPS_Y="$APP_Y"
TITLEBAR="${TITLEBAR:-28}"
WIN_L=300; WIN_T=200
WIN_R=$((WIN_L + WIN_W)); WIN_B=$((WIN_T + WIN_H + TITLEBAR))

# A single space gives the Applications alias a blank (invisible) label.
APPS_NAME=" "

echo "==> Layout: window ${WIN_W}x${WIN_H} pt, icons ${ICON_SIZE} pt, bg ${DPI} dpi"

WORK="$(mktemp -d)"
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"

echo "==> Staging"
cp -R "$APP_SRC" "$STAGE/$APP_IN_DMG"
ln -s /Applications "$STAGE/$APPS_NAME"
cp "$BG_SRC" "$STAGE/.background/background.png"
sips -s dpiWidth "$DPI" -s dpiHeight "$DPI" "$STAGE/.background/background.png" >/dev/null
# NOTE: the volume icon is applied AFTER Finder styling (see below) — Finder's
# open pass strips a .VolumeIcon.icns staged this early.

echo "==> Creating writable DMG"
RW_DMG="$WORK/rw.dmg"
hdiutil create -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW -size 256m "$RW_DMG" >/dev/null

MOUNT="/Volumes/$VOLNAME"
[ -d "$MOUNT" ] && hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
hdiutil attach "$RW_DMG" -noautoopen -nobrowse >/dev/null

echo "==> Styling window via Finder"
osascript <<EOF || echo "   (Finder styling reported an issue; DMG still built)"
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {$WIN_L, $WIN_T, $WIN_R, $WIN_B}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to $ICON_SIZE
    set background picture of opts to file ".background:background.png"
    set position of item "$APP_IN_DMG" of container window to {$APP_X, $APP_Y}
    set position of item "$APPS_NAME" of container window to {$APPS_X, $APPS_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

# Apply the custom volume icon LAST — Finder's styling pass strips a .VolumeIcon.icns
# staged earlier, so copy it in now, after the window is configured.
if [ -f "$VOLICON" ]; then
  echo "==> Setting volume icon"
  cp "$VOLICON" "$MOUNT/.VolumeIcon.icns"
  SetFile -a C "$MOUNT"                    # volume uses a custom icon
  SetFile -a V "$MOUNT/.VolumeIcon.icns"   # hide the icon file itself
fi

# Guard: Finder writes the window styling into .DS_Store. If it's missing, the
# styling silently failed (typically when run headless / from a background process
# that can't drive Finder) — abort rather than ship an unstyled DMG.
if [ ! -f "$MOUNT/.DS_Store" ]; then
  echo "!! No .DS_Store was written — Finder window styling failed." >&2
  echo "!! Run this from a foreground Terminal with GUI access (not a background/headless process)." >&2
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  exit 1
fi

sync
echo "==> Finalizing"
hdiutil detach "$MOUNT" >/dev/null
rm -f "$OUT_DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG" >/dev/null
rm -rf "$WORK"
echo "==> Done: $OUT_DMG"
