import SwiftUI
import AppKit

@main
struct IPFSOpenerApp: App {
    @State private var prefs: Preferences
    @State private var model: AppModel

    init() {
        let preferences = Preferences()
        _prefs = State(initialValue: preferences)
        _model = State(initialValue: AppModel(prefs: preferences))
    }

    var body: some Scene {
        Window("IPFS Opener", id: "main") {
            ContentView()
                .environment(model)
                .environment(prefs)
        }
        .windowResizability(.contentSize)
        .commands {
            // A single-purpose utility window: drop the "New Window" command.
            CommandGroup(replacing: .newItem) {}
            // Put the privacy statement in the standard About panel.
            CommandGroup(replacing: .appInfo) {
                Button("About IPFS Opener") { showAboutPanel() }
            }
        }

        Settings {
            SettingsView()
                .environment(prefs)
        }
    }

    /// Shows the standard About panel with the privacy statement in its credits area.
    private func showAboutPanel() {
        let text = """
        IPFS Opener keeps no history and collects no analytics.

        The gateway (as set in Settings) can see the requested CID and your public \
        network address.
        """
        let credits = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
