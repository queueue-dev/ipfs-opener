import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var prefs

    @State private var gatewayDraft = ""
    @State private var gatewayError = false
    @FocusState private var gatewayFocused: Bool

    var body: some View {
        @Bindable var prefs = prefs

        Form {
            Section("Preferred gateway") {
                // The field commits live (on Return or when focus leaves), so it
                // always shows the gateway currently in use — no separate readout.
                TextField("Gateway", text: $gatewayDraft, prompt: Text("https://dweb.link"))
                    .textFieldStyle(.roundedBorder)
                    .focused($gatewayFocused)
                    .onSubmit(commitGateway)
                    .onChange(of: gatewayFocused) { _, isFocused in
                        if !isFocused { commitGateway() }
                    }
                    .accessibilityLabel("Preferred gateway address")

                if gatewayError {
                    Label("That isn’t a valid gateway. Use an https address like https://dweb.link.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Restore Default") {
                    gatewayDraft = GatewayConfig.defaultGateway
                    commitGateway()
                }

                Text("Advanced: include {cid} and {path} to build a custom URL pattern.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pasted gateway URLs") {
                Picker("When I paste a gateway URL", selection: $prefs.existingURLHandling) {
                    ForEach(ExistingURLHandling.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
            }

            Section("After opening") {
                Picker("After opening a link", selection: $prefs.afterOpen) {
                    ForEach(AfterOpenBehavior.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
            }

            Section("Security & convenience") {
                Toggle("Warn before using an insecure http gateway", isOn: $prefs.warnOnPlainHttp)
                Toggle("Check the clipboard for an IPFS address on launch", isOn: $prefs.checkClipboardOnLaunch)
            }

            Section("Fallback gateways") {
                Toggle("Automatically fall back to another gateway", isOn: $prefs.enableFallback)
                Text("When enabled, IPFS Opener briefly checks your preferred gateway and, if it's unreachable, opens through the next one instead. Off by default; this is the only time the app itself uses the network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if prefs.enableFallback {
                    Text("Fallback order: " + prefs.fallbackGateways.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(minHeight: 560)
        .onAppear { gatewayDraft = prefs.preferredGateway }
    }

    /// Validates the draft and saves it if it changed. Invalid input surfaces an
    /// inline error and leaves the draft in place so the user can correct it.
    private func commitGateway() {
        let candidate = gatewayDraft.trimmingCharacters(in: .whitespaces)
        if candidate == prefs.preferredGateway {
            gatewayError = false
            return
        }
        if GatewayResolver.validateGateway(candidate) {
            prefs.preferredGateway = candidate
            gatewayDraft = candidate
            gatewayError = false
        } else {
            gatewayError = true
        }
    }
}
