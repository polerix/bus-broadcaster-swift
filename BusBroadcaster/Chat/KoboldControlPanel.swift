import SwiftUI

// MARK: - Panel mode

private enum KoboldMode: Equatable {
    case none, note, chat, cache
}

// MARK: - KoboldControlPanel

struct KoboldControlPanel: View {
    @EnvironmentObject var turnQueue: TurnQueue
    @State private var mode:        KoboldMode = .none
    @State private var inputText:   String     = ""
    @State private var newItemText: String     = ""
    @State private var blink:       Bool       = false
    @FocusState private var inputFocused: Bool

    private let koboldPurple = Color(hex: "#9B7FD4")
    private let blinker = Timer.publish(every: 0.9, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Expanded content slides in above the bar
            if mode != .none {
                expandedPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            controlBar
        }
        .animation(.easeInOut(duration: 0.18), value: mode)
        .onReceive(blinker) { _ in blink.toggle() }
    }

    // ── Control bar ────────────────────────────────────────────────────────────

    private var controlBar: some View {
        HStack(spacing: 0) {
            // Kobold indicator
            HStack(spacing: 5) {
                Text("👾")
                    .font(.system(size: 11))
                    .opacity(turnQueue.koboldAcknowledged ? (blink ? 1.0 : 0.3) : 0.25)
                Text("KOBOLD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        turnQueue.koboldAcknowledged
                            ? koboldPurple.opacity(blink ? 1.0 : 0.5)
                            : koboldPurple.opacity(0.25)
                    )
            }
            .frame(width: 76, alignment: .leading)
            .padding(.leading, 10)

            Divider().frame(height: 16).background(Color.white.opacity(0.1))

            // Mode buttons
            modeButton(icon: "note.text",   label: "NOTE",  target: .note)
            modeButton(icon: "mic",         label: "SPEAK", target: .chat)
            modeButton(icon: "archivebox",  label: "CACHE", target: .cache)

            Spacer()

            // Item count badge
            if !turnQueue.koboldInventory.isEmpty {
                Text("\(turnQueue.koboldInventory.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(koboldPurple)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(koboldPurple.opacity(0.15))
                    .cornerRadius(3)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: 28)
        .background(
            turnQueue.koboldAcknowledged
                ? koboldPurple.opacity(0.08)
                : Color.black.opacity(0.5)
        )
        .overlay(Rectangle().frame(height: 1).foregroundColor(
            koboldPurple.opacity(turnQueue.koboldAcknowledged ? 0.4 : 0.12)
        ), alignment: .top)
    }

    private func modeButton(icon: String, label: String, target: KoboldMode) -> some View {
        let active = mode == target
        return Button {
            mode = active ? .none : target
            if mode != .none { inputFocused = true }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: active ? .bold : .regular, design: .monospaced))
            }
            .foregroundColor(active ? koboldPurple : koboldPurple.opacity(0.45))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(active ? koboldPurple.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // ── Expanded panel ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var expandedPanel: some View {
        switch mode {
        case .note:  notePanel
        case .chat:  chatPanel
        case .cache: cachePanel
        case .none:  EmptyView()
        }
    }

    // ── Note panel ────────────────────────────────────────────────────────────

    private var notePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelLabel("📝  LEAVE A NOTE")

            HStack(spacing: 6) {
                TextField("Write something cryptic…", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .focused($inputFocused)
                    .onSubmit { slipNote() }

                sendButton("SLIP") { slipNote() }
            }
            .padding(.horizontal, 10)

            // Future options — grayed out placeholders
            HStack(spacing: 12) {
                placeholderOption(icon: "mappin", label: "LOCATION", value: "unknown")
                placeholderOption(icon: "timer",  label: "PERSISTS",  value: "∞")
                Spacer()
                Text("(specify later)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.15))
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.04, blue: 0.10))
        .overlay(Rectangle().frame(height: 1).foregroundColor(koboldPurple.opacity(0.25)), alignment: .top)
    }

    private func slipNote() {
        turnQueue.leaveKoboldNote(inputText)
        inputText = ""
        mode = .none
    }

    // ── Chat panel ────────────────────────────────────────────────────────────

    private var chatPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelLabel("💬  SPEAK AS KOBOLD")

            HStack(spacing: 6) {
                TextField("Say something wrong…", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(koboldPurple.opacity(0.9))
                    .focused($inputFocused)
                    .onSubmit { sendChat() }

                sendButton("SEND") { sendChat() }
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.04, blue: 0.10))
        .overlay(Rectangle().frame(height: 1).foregroundColor(koboldPurple.opacity(0.25)), alignment: .top)
    }

    private func sendChat() {
        turnQueue.sendKoboldChat(inputText)
        inputText = ""
        mode = .none
    }

    // ── Cache panel ───────────────────────────────────────────────────────────

    private var cachePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            panelLabel("📦  KOBOLD CACHE")

            if turnQueue.koboldInventory.isEmpty {
                Text("nothing here yet")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.horizontal, 10)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(turnQueue.koboldInventory) { item in
                            HStack(spacing: 6) {
                                Text("◆")
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(koboldPurple.opacity(0.6))
                                Text(item.name)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.75))
                                Spacer()
                                Text(item.ageLabel)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.2))
                                Button {
                                    turnQueue.removeFromKoboldCache(id: item.id)
                                } label: {
                                    Text("−")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(koboldPurple.opacity(0.7))
                                        .frame(width: 18, height: 18)
                                        .background(koboldPurple.opacity(0.12))
                                        .cornerRadius(3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 80)
            }

            // Add item row
            HStack(spacing: 6) {
                Text("+")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(koboldPurple.opacity(0.6))
                TextField("name an item…", text: $newItemText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .focused($inputFocused)
                    .onSubmit { addItem() }
                sendButton("ADD") { addItem() }
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.04, blue: 0.10))
        .overlay(Rectangle().frame(height: 1).foregroundColor(koboldPurple.opacity(0.25)), alignment: .top)
    }

    private func addItem() {
        turnQueue.addToKoboldCache(newItemText)
        newItemText = ""
    }

    // ── Shared sub-views ──────────────────────────────────────────────────────

    private func panelLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(koboldPurple.opacity(0.6))
            .padding(.horizontal, 10)
    }

    private func sendButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(koboldPurple)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(koboldPurple.opacity(0.18))
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(koboldPurple.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
    }

    private func placeholderOption(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(label): \(value)")
                .font(.system(size: 8, design: .monospaced))
        }
        .foregroundColor(.white.opacity(0.2))
    }
}
