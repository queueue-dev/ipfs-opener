# IPFS Opener — Enhancements Log

Tracking work intentionally deferred beyond the 1.0 MVP. Not bugs — planned improvements.

## Packaging & branding
- [x] **Stylized DMG installer.** Done — `scripts/make_styled_dmg.sh` (called by
      `build_release.sh`) produces a 648×428-pt window, 128-pt icons, background art
      (`packaging/installer_background.png`), Applications alias with a blanked label.
- [x] **Custom disk image / volume icon.** Done — `packaging/VolumeIcon.icns` set as the
      volume's custom icon.
- [x] **App icon artwork.** Done — 1024px master supplied by Matt, all 16–512pt @1x/@2x
      sizes generated into `Assets.xcassets/AppIcon.appiconset`.
- [x] **App-name label in the DMG.** Decision: **accept it** (Finder always shows the app
      bundle's name; can't be hidden without misnaming the install). No background-darkening.

## Release & distribution

> **Identity guardrail (do not get this wrong):** everything public ships under
> **Queueue Studios LLC**, not the personal identity.
> - **GitHub:** repo, all commits, and releases use the **`queueue-dev`** user — NOT
>   `mattonchain`. Set local `git config user.name`/`user.email` to queueue-dev's before the
>   first commit, and `gh auth` as queueue-dev.
> - **Apple:** sign/notarize with the **Queueue Studios LLC** Apple Developer account,
>   team **`J87JRCN9RM`**, "Developer ID Application: Queueue Studios LLC" (already wired
>   into the project and `build_release.sh`).

- [x] **Public GitHub repo** — https://github.com/queueue-dev/ipfs-opener (owned by
      `queueue-dev`, MIT, README rendering). Commits attributed to Queueue Studios LLC via
      the `299584394+queueue-dev@users.noreply.github.com` noreply email.
  - [ ] README polish: add screenshots once available.
- [x] **LICENSE** file — MIT, © 2026 Queueue Studios LLC.
- [x] **`.gitignore`** — excludes `build/`, DerivedData, `*.dmg`, `.DS_Store`, xcuserdata,
      local settings, and credential files.
- [x] **Sign & notarize** — v1.0.0 built via `build_release.sh`: Developer ID (Queueue
      Studios LLC), Hardened Runtime, notarized + stapled **twice** (app and DMG, so the
      extracted app passes Gatekeeper offline). Notary profile `ipfs-opener`.
- [x] **GitHub Release** — https://github.com/queueue-dev/ipfs-opener/releases/tag/v1.0.0
      with `IPFS-Opener-1.0.0.dmg` attached.
- [ ] **Screenshots / hero image** for the README and repo social preview.
- [ ] **Website listing** — add an IPFS Opener blurb to https://queueue.tv/other-apps,
      under the OpenObject section.
- [ ] *(Optional)* Clean-machine Gatekeeper test — largely covered by app-stapling
      (offline-safe), but a true never-saw-the-cert Mac is the final proof.
- [ ] *(Optional)* **CI** (GitHub Actions) to build + run tests on PRs; notarize on tags.
- [ ] *(Optional)* **Auto-update** (Sparkle) and/or a **Homebrew Cask** for easier install.
- [ ] *(Optional)* Host `PRIVACY.md` at a public URL to link from the app/README.

## Functionality
- [x] **Automatic gateway fallback.** Done — `GatewayResolver.resolve()` probes gateway
      health (HEAD to the root, 2.5 s timeout) and opens the first reachable of
      dweb.link → ipfs.io → 4everland.io → ipfs.filebase.io. Off by default (zero-network
      default preserved); `com.apple.security.network.client` entitlement added; Settings
      toggle live. Switches only on connection/DNS/timeout/5xx — never on a content 404.
- [ ] **Remote/auto-updated gateway list** (opt-in, off by default) — `allowRemoteGatewayList`
      key is reserved for this; could pull `ipfs/public-gateway-checker`'s `gateways.json`.

## Future functionality
- [ ] **Backend logging** of IPFS content location plus related metadata (opt-in; must
      respect the "no history by default" privacy stance). Would likely require the network
      entitlement and a clear settings toggle + privacy disclosure.
- [ ] **`ipfs://` URL-scheme handler** — register the app to handle `ipfs://` links so they
      can be opened from other apps (adds `CFBundleURLTypes`).
- [ ] **IPNS polish** — currently accepted with light validation; could add stricter
      libp2p-key / DNSLink validation.
