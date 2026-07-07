# IPFS Opener — Privacy

IPFS Opener is built to do one thing and get out of the way.

## What it does not do
- **No history.** The app does not store, log, or persist the CIDs or links you enter.
- **No analytics.** There is no telemetry, tracking, or usage reporting of any kind.
- **No accounts.** The app has no login and collects nothing about you.
- **No network of its own — by default.** Normally the app makes **no** network requests; it
  hands the constructed `https` URL to your default browser, and the browser performs the
  fetch. The one exception is the optional **fallback gateways** setting (off by default):
  when enabled, the app sends a brief reachability check to your preferred gateway (and, if
  it's down, the next one) before opening. No content is downloaded by the app, and nothing
  is stored.

## What you should know
- **Your gateway can see your requests.** Whichever IPFS gateway you use (the default is
  `https://dweb.link`) can observe the CID you request and your network address, because
  your browser connects to it directly. The active gateway is always shown in Settings so
  you know which service is retrieving your content. You can change it at any time.
- **Clipboard.** On launch, the app reads the clipboard once to see whether it already
  holds a recognizable IPFS address, and if so pre-fills the field. Nothing is opened
  automatically and nothing is stored. This can be turned off in Settings.
- **Preferences** (your chosen gateway and behavior options) are stored locally in macOS
  `UserDefaults`. They never leave your Mac.

## Sandbox
IPFS Opener runs inside the macOS App Sandbox with no file or hardware entitlements and no
administrator privileges. Its only entitlement is outbound network client access, used
solely for the optional gateway reachability check described above.
