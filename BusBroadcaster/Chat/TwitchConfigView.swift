import SwiftUI

// MARK: - TwitchConfigView
/// Twitch integration settings sheet.
/// Accessible via ⌘, (macOS Settings scene) or the Broadcast menu.
struct TwitchConfigView: View {

    @EnvironmentObject private var bridge: TwitchChatBridge

    @State private var tokenEntry:    String = ""
    @State private var tokenRevealed: Bool   = false

    var body: some View {
        Form {
            // ── Channel ────────────────────────────────────────────────
            Section("Channel") {
                HStack {
                    Text("#")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    TextField("channel name", text: $bridge.channelName)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
            }

            // ── OAuth Token ────────────────────────────────────────────
            Section("OAuth Token") {
                HStack {
                    if tokenRevealed {
                        TextField("token", text: $tokenEntry)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("token", text: $tokenEntry)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(tokenRevealed ? "Hide" : "Show") {
                        tokenRevealed.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                Button("Save token to Keychain") {
                    TwitchKeychainStore.store(tokenEntry)
                    tokenEntry = ""
                }
                .disabled(tokenEntry.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#9146FF"))
            }

            // ── Message Filter ─────────────────────────────────────────
            Section("Message Filter") {
                Toggle(isOn: $bridge.filterInteractionsOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interactions only")
                        Text("Show only messages starting with ! commands")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // ── Connection ─────────────────────────────────────────────
            Section("Connection") {
                HStack {
                    Circle()
                        .fill(bridge.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(bridge.isConnected
                         ? "Connected to #\(bridge.channelName)"
                         : "Disconnected")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    if bridge.isConnected {
                        Button("Disconnect") { bridge.disconnect() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Connect") { bridge.connect() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "#9146FF"))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 420, idealWidth: 480, minHeight: 340)
        .navigationTitle("Twitch Chat")
        .onAppear { tokenEntry = "" }
    }
}
