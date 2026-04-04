import SwiftUI

struct ChatPanelView: View {
    @EnvironmentObject var turnQueue: TurnQueue

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            chatScrollArea
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 10) {
            Text("📡 BROADCAST CHANNEL")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(Color(hex: "#A8E6CF"))
            Spacer()
            if turnQueue.isRunning {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                        .opacity(turnQueue.currentSpeaker != nil ? 1.0 : 0.4)
                    Text("LIVE")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .cornerRadius(3)
            } else {
                Text("OFF AIR")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
            if let speaker = turnQueue.currentSpeaker {
                Text("\(speaker) is speaking…")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Scroll area

    private var chatScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(turnQueue.messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: turnQueue.messages.count) { _, _ in
                if let last = turnQueue.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    @EnvironmentObject var moodRegistry: MoodRegistry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Name + EmoBar mood indicator — fixed column
            VStack(alignment: .trailing, spacing: 2) {
                Text(message.character)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(message.nameColor)
                    .lineLimit(1)
                MoodIndicatorView(mood: moodRegistry.mood(for: message.character))
            }
            .frame(width: 108, alignment: .trailing)

            // Message text with streaming cursor
            Text(message.isStreaming ? message.text + "▌" : message.text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Timestamp
            Text(message.timestamp, style: .time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
        }
    }
}
