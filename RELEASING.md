# Releasing IPFS Opener

How to produce the signed, notarized DMG and publish a release. Maintainer reference.

## Identity

Everything ships under **Queueue Studios LLC** — Apple team `J87JRCN9RM`, GitHub `queueue-dev`.
`scripts/build_release.sh` already defaults to the Queueue Studios signing identity.

## One-time setup

- A **Developer ID Application** certificate for Queueue Studios LLC in your login keychain.
- Stored `notarytool` credentials (an app-specific password from
  [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords):

  ```bash
  xcrun notarytool store-credentials "IPFSOpener-Notary" \
    --apple-id "<your Queueue Studios Apple ID>" \
    --team-id J87JRCN9RM \
    --password "<app-specific password>"
  ```

## Build

```bash
./scripts/build_release.sh
```

The script: archives (Universal, Hardened Runtime) → exports a Developer ID app → builds the
styled DMG (background art, 128-pt icons, custom volume icon) → signs it → submits to Apple
for notarization and waits → staples the ticket → runs a Gatekeeper check.

Output: **`build/IPFS Opener.dmg`**

Override defaults via environment variables if needed:
`SIGN_IDENTITY`, `TEAM_ID`, `NOTARY_PROFILE`, `SKIP_NOTARIZE=1` (to build without notarizing).

Styled-DMG assets live in `packaging/` (`installer_background.png`, `VolumeIcon.icns`) and are
picked up automatically.

## Verify

```bash
spctl -a -vvv --type install "build/IPFS Opener.dmg"   # should report: accepted, Developer ID
stapler validate "build/IPFS Opener.dmg"
```

Ideally, also open the DMG on a Mac that has never seen the signing cert to confirm Gatekeeper
lets it through cleanly.

## Publish

Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the Xcode project, tag, and attach the
DMG to a GitHub Release (as `queueue-dev`):

```bash
gh release create v1.0.0 "build/IPFS Opener.dmg" \
  --title "IPFS Opener 1.0.0" \
  --notes "First release."
```
