# IPFS Opener

A tiny, native macOS app: paste an IPFS CID or address, press Return, and the content
opens in your default browser. No IPFS Desktop, Kubo, Homebrew, or browser extension
required.

## Install

1. Download the latest **IPFS Opener.dmg** from the
   [Releases](https://github.com/queueue-studios/ipfs-opener/releases) page.
2. Open the DMG and drag **IPFS Opener** into your **Applications** folder.
3. Launch it from Applications.

Requires **macOS 15 or later** (Universal — Apple Silicon and Intel). The app is signed with
a Developer ID and notarized by Apple, so it opens without security warnings.

## Usage

1. Open the app — the text field is focused automatically (and pre-filled if your clipboard
   already holds an IPFS address).
2. Paste a CID or link.
3. Press **Return** or click **Open**.
4. The content opens in your default browser via an `https` gateway.

### Supported input
- Bare CID — CIDv0 (`Qm…`) and CIDv1 (`bafy…` and other multibase/codec prefixes)
- `ipfs://CID`, `ipfs://CID/path/to/file.html`
- `/ipfs/CID`, `/ipfs/CID/path/to/file`
- Existing gateway URLs — path-style (`https://ipfs.io/ipfs/CID`) and subdomain-style
  (`https://CID.ipfs.dweb.link`), with or without the `https://` scheme
  (`ipfs.io/ipfs/CID`); opened as-is by default, or rewritten through your
  preferred gateway (Settings)
- CID with a path, and preserved query strings / fragments
  (`CID/index.html?mode=display#section`)

CIDs are validated locally with a small, dependency-free multiformats parser that understands
CIDv0/v1, multibase prefixes, multicodec values, and multihash structure — it does **not**
hardcode `Qm`/`bafy` and will not reject a valid but unfamiliar prefix.

## Privacy

No history, no analytics. The app makes **no network requests of its own** by default — the
browser does all fetching. The optional gateway-fallback setting is the only exception. See
[PRIVACY.md](PRIVACY.md).

## Building from source

Requires **Xcode 16 or later**.

```bash
# Run the tests
xcodebuild test -scheme IPFSOpener -destination 'platform=macOS'

# Build a Release app (Universal)
xcodebuild build -scheme IPFSOpener -configuration Release -destination 'generic/platform=macOS'
```

Producing a signed, notarized DMG for distribution is documented in [RELEASING.md](RELEASING.md).

### Architecture
```
raw input → InputClassifier → CIDParser → ParsedInput → GatewayResolver.resolve() → URL → default browser
```
`GatewayResolver.resolve()` is the single, `async` choke point. By default it performs no
network activity. With the optional **fallback gateways** setting enabled, it probes gateway
reachability and opens the first of `dweb.link → ipfs.io → 4everland.io → ipfs.filebase.io`
that's up, switching only on infrastructure failure (never on a content 404).

## License

MIT — see [LICENSE](LICENSE). © 2026 Queueue Studios LLC.
