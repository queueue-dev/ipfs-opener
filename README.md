# IPFS Opener

A tiny, native macOS app: paste an IPFS CID or address, press Return, and the content
opens in your default browser. No IPFS Desktop, Kubo, Homebrew, or browser extension
required.

## Workflow
1. Open the app — the text field is focused automatically (and pre-filled if your
   clipboard already holds an IPFS address).
2. Paste a CID or link.
3. Press **Return** or click **Open**.
4. The content opens in your default browser via an `https` gateway.

## Supported input
- Bare CID — CIDv0 (`Qm…`) and CIDv1 (`bafy…` and other multibase/codec prefixes)
- `ipfs://CID`, `ipfs://CID/path/to/file.html`
- `/ipfs/CID`, `/ipfs/CID/path/to/file`
- Existing gateway URLs — path-style (`https://ipfs.io/ipfs/CID`) and subdomain-style
  (`https://CID.ipfs.dweb.link`); opened as-is by default, or rewritten through your
  preferred gateway (Settings)
- CID with a path, and preserved query strings / fragments
  (`CID/index.html?mode=display#section`)

CIDs are validated locally with a small, dependency-free multiformats parser
(`IPFSOpener/Parsing/`) that understands CIDv0/v1, multibase prefixes, multicodec values,
and multihash structure — it does **not** hardcode `Qm`/`bafy` and will not reject a valid
but unfamiliar prefix.

## Architecture
```
raw input → InputClassifier → CIDParser → ParsedInput → GatewayResolver.resolve() → URL → default browser
```
`GatewayResolver.resolve()` is the single, `async` choke point. By default the app makes
**no network calls of its own** — the browser does all fetching. The optional **fallback
gateways** setting (off by default) is the one exception: when enabled, the resolver probes
gateway reachability and opens the first of `dweb.link → ipfs.io → 4everland.io →
ipfs.filebase.io` that's up, switching only on infrastructure failure (never on a content
404).

## Requirements
- macOS 15 or later (Universal — Apple Silicon and Intel)
- Xcode 16+ to build

## Build & test
```bash
xcodebuild test  -scheme IPFSOpener -destination 'platform=macOS'
xcodebuild build -scheme IPFSOpener -configuration Release -destination 'generic/platform=macOS'
```

## Package for distribution
Signed + notarized DMG (Developer ID, Hardened Runtime, App Sandbox):
```bash
SIGN_IDENTITY="Developer ID Application: <you> (<TEAMID>)" \
TEAM_ID="<TEAMID>" \
NOTARY_PROFILE="IPFSOpener-Notary" \
./scripts/build_release.sh
```
See the script header for the one-time `notarytool store-credentials` setup. Drop styled
DMG assets into `packaging/` (`dmg-background.png`, `VolumeIcon.icns`) to have them picked
up automatically.

## Privacy
No history, no analytics. The app makes no network requests of its own by default — the
optional gateway-fallback setting is the only exception. See [PRIVACY.md](PRIVACY.md).

## License
MIT — see [LICENSE](LICENSE). © 2026 Queueue Studios LLC.
