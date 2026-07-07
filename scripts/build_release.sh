#!/bin/bash
#
# build_release.sh — Archive, sign (Developer ID + Hardened Runtime), notarize,
# staple, and package IPFS Opener as a distributable DMG.
#
# Prerequisites (one-time):
#   • A "Developer ID Application" certificate in your login keychain.
#   • A stored notarytool credential profile:
#       xcrun notarytool store-credentials "IPFSOpener-Notary" \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage:
#   TEAM_ID=J87JRCN9RM \
#   SIGN_IDENTITY="Developer ID Application: Queueue Studios LLC (J87JRCN9RM)" \
#   NOTARY_PROFILE="IPFSOpener-Notary" \
#   ./scripts/build_release.sh
#
set -euo pipefail

# --- Configuration (override via environment) --------------------------------
SCHEME="IPFSOpener"
CONFIGURATION="Release"
APP_NAME="IPFS Opener"          # display name used for the .app and .dmg
PRODUCT_NAME="IPFS Opener"      # PRODUCT_NAME (matches the built .app / executable)

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Queueue Studios LLC (J87JRCN9RM)}"
TEAM_ID="${TEAM_ID:-J87JRCN9RM}"
NOTARY_PROFILE="${NOTARY_PROFILE:-IPFSOpener-Notary}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/$PRODUCT_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_STAGE="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$PRODUCT_NAME.dmg"

# Optional styled-DMG assets (drop them in when ready).
DMG_BACKGROUND="${DMG_BACKGROUND:-$ROOT/packaging/dmg-background.png}"   # 660x400 recommended
DMG_VOLICON="${DMG_VOLICON:-$ROOT/packaging/VolumeIcon.icns}"

echo "==> Cleaning"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DMG_STAGE"

echo "==> Archiving (universal, Hardened Runtime, Developer ID)"
xcodebuild archive \
  -project "$ROOT/IPFSOpener.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  ${TEAM_ID:+DEVELOPMENT_TEAM="$TEAM_ID"} \
  ENABLE_HARDENED_RUNTIME=YES

# --- Export the signed .app from the archive ---------------------------------
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    ${TEAM_ID:+<key>teamID</key><string>$TEAM_ID</string>}
</dict>
</plist>
PLIST

echo "==> Exporting Developer ID app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

APP_PATH="$EXPORT_DIR/$PRODUCT_NAME.app"
[ -d "$APP_PATH" ] || { echo "!! Exported app not found at $APP_PATH"; exit 1; }

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP_PATH"

# --- Build the styled DMG ----------------------------------------------------
# Layout locked from the design pass: 648×428-pt window (648×396 content + 32-pt
# title bar), 128-pt icons, background art at packaging/installer_background.png,
# custom volume icon at packaging/VolumeIcon.icns.
echo "==> Building styled DMG"
rm -f "$DMG_PATH"
WIN_W=648 ICON_SIZE=128 TITLEBAR=32 "$ROOT/scripts/make_styled_dmg.sh" "$APP_PATH" "$DMG_PATH"

echo "==> Signing the DMG"
codesign --force --sign "$SIGN_IDENTITY" ${TEAM_ID:+--timestamp} "$DMG_PATH"

# --- Notarize ----------------------------------------------------------------
if [ "$SKIP_NOTARIZE" = "1" ]; then
  echo "==> Skipping notarization (SKIP_NOTARIZE=1)"
else
  echo "==> Submitting for notarization (this waits for Apple)"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo "==> Gatekeeper assessment"
spctl -a -vvv --type install "$DMG_PATH" || true

echo "==> Done: $DMG_PATH"
