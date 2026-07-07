import AppKit
import Observation

/// Drives the main-window workflow: classify → resolve → open in the default browser.
@MainActor
@Observable
final class AppModel {

    /// A status/validation message shown inline in the window.
    struct StatusMessage: Equatable {
        enum Kind: Equatable { case error, warning, success }
        var kind: Kind
        var text: String
        /// SF Symbol name; the icon (not color alone) communicates the kind.
        var symbol: String
    }

    var inputText: String = ""
    var message: StatusMessage?
    /// Set when the resolved URL is plain http and the user must confirm.
    var pendingInsecureURL: URL?
    /// Incremented to ask the view to re-focus and select all text.
    private(set) var selectAllToken: Int = 0
    /// True after an open when the "keep window open and select" behavior is
    /// active, so the field is re-selected when the app is brought back to front
    /// (the browser steals focus at open time, so an immediate select is lost).
    var pendingReselect = false

    let prefs: Preferences
    /// Guards against re-entry while an async gateway probe is in flight.
    private var isOpening = false

    init(prefs: Preferences) {
        self.prefs = prefs
    }

    /// Classifies and opens the current input.
    func openFromInput() async {
        if isOpening { return }
        isOpening = true
        defer { isOpening = false }

        pendingInsecureURL = nil
        pendingReselect = false

        switch InputClassifier.classify(inputText) {
        case .failure(let error):
            message = Self.message(for: error)
        case .success(let parsed):
            switch await GatewayResolver.resolve(parsed, config: prefs.gatewayConfig) {
            case .failure:
                message = StatusMessage(kind: .error,
                                        text: "This does not appear to be a valid IPFS address.",
                                        symbol: "exclamationmark.triangle")
            case .success(let url):
                if url.scheme?.lowercased() == "http", prefs.warnOnPlainHttp {
                    pendingInsecureURL = url
                    message = StatusMessage(kind: .warning,
                                            text: "This gateway uses an insecure http connection.",
                                            symbol: "lock.open.trianglebadge.exclamationmark")
                    return
                }
                open(url)
            }
        }
    }

    /// Opens the pending http URL after the user confirms.
    func confirmInsecureOpen() {
        guard let url = pendingInsecureURL else { return }
        pendingInsecureURL = nil
        open(url)
    }

    /// Prefills the field from the clipboard when it holds a recognizable IPFS
    /// address. Never opens automatically.
    func loadClipboardIfEnabled() {
        guard prefs.checkClipboardOnLaunch, inputText.isEmpty else { return }
        guard let clip = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if case .success = InputClassifier.classify(trimmed) {
            inputText = trimmed
            selectAllToken += 1
        }
    }

    // MARK: - Private

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
        message = StatusMessage(kind: .success, text: "Opened in your default browser.", symbol: "checkmark.circle")
        applyAfterOpen()
    }

    private func applyAfterOpen() {
        switch prefs.afterOpen {
        case .keepOpenAndSelect:
            selectAllToken += 1     // in case the app stays active
            pendingReselect = true  // and reselect when it's brought back to front
        case .keepOpenAndClear:
            inputText = ""
            selectAllToken += 1 // re-focus the now-empty field
        case .closeWindow:
            NSApp.keyWindow?.close()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    static func message(for error: InputError) -> StatusMessage {
        switch error {
        case .empty:
            return StatusMessage(kind: .error, text: "Enter an IPFS CID or IPFS link.", symbol: "exclamationmark.circle")
        case .unsupportedScheme(let scheme):
            return StatusMessage(kind: .error, text: "The URL scheme \u{201C}\(scheme)\u{201D} is not supported.", symbol: "exclamationmark.triangle")
        case .invalidAddress:
            return StatusMessage(kind: .error, text: "This does not appear to be a valid IPFS address.", symbol: "exclamationmark.triangle")
        }
    }
}
