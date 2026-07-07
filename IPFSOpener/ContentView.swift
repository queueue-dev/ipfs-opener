import SwiftUI
import AppKit
import Combine

/// The single, compact main window.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            header

            TextField("Paste an IPFS CID or link", text: $model.inputText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .focused($fieldFocused)
                .onSubmit { Task { await model.openFromInput() } }
                .accessibilityLabel("IPFS CID or link")

            if let message = model.message {
                messageView(message)
            }

            controls
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            fieldFocused = true
            model.loadClipboardIfEnabled()
        }
        .onChange(of: model.selectAllToken) {
            fieldFocused = true
            selectAllInFocusedField()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // The browser stole focus when we opened the URL; now that we're back
            // in front, reapply the selection the user asked to keep.
            if model.pendingReselect {
                model.pendingReselect = false
                fieldFocused = true
                selectAllInFocusedField()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cube.transparent")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("IPFS Opener")
                .font(.headline)
            Spacer()
        }
    }

    /// Selects all text in the currently focused field (the field editor).
    private func selectAllInFocusedField() {
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    private var controls: some View {
        HStack {
            if model.pendingInsecureURL != nil {
                Button("Open anyway (insecure)") {
                    model.confirmInsecureOpen()
                }
                .accessibilityHint("Opens the address over an insecure http connection")
            }
            Spacer()
            Button("Open") {
                Task { await model.openFromInput() }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func messageView(_ message: AppModel.StatusMessage) -> some View {
        let color: Color = switch message.kind {
        case .error: .red
        case .warning: .orange
        case .success: .green
        }
        return Label {
            Text(message.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: message.symbol)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}
