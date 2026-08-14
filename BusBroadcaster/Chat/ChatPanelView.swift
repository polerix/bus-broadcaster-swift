import SwiftUI
import Combine

// MARK: - DisplayItem
/// Unified envelope for crew ChatMessages and Twitch ViewerMessages,
/// enabling a single sorted timeline in the chat scroll view.
enum DisplayItem: Identifiable {
    case crew(ChatMessage)
    case viewer(ViewerMessage)

    var id: UUID {
        switch self {
        case .crew(let m):    return m.id
        case .viewer(let m):  return m.id
        }
    }

    var timestamp: Date {
        switch self {
        case .crew(let m):   return m.timestamp
        case .viewer(let m): return m.timestamp
        }
    }
}

// MARK: - ChatPanelView
struct ChatPanelView: View {
    @EnvironmentObject var turnQueue:    TurnQueue
    @EnvironmentObject var twitchBridge: TwitchChatBridge

    /// Unified timeline — appended in arrival order by onChange / onReceive.
    @State private var timeline: [DisplayItem] = []

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            chatScrollArea
            KoboldControlPanel()
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        // Sync crew messages into the unified timeline
        .onChange(of: turnQueue.messages.count) { _ in
            syncCrewMessages()
        }
        // Append incoming Twitch messages to the timeline
        .onReceive(twitchBridge.messagePublisher) { msg in
            timeline.append(.viewer(msg))
        }
        .onAppear {
            syncCrewMessages()
        }
    }

    // MARK: - Sync helpers

    private func syncCrewMessages() {
        // Rebuild crew slice; viewer items are kept intact.
        let viewerItems = timeline.filter {
            if case .viewer = $0 { return true }
            return false
        }
        let crewItems = turnQueue.messages.map { DisplayItem.crew($0) }
        // Merge and re-sort by timestamp so viewer messages slot in correctly.
        timeline = (crewItems + viewerItems).sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 10) {
            Text("📡 BROADCAST CHANNEL")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(Color(hex: "#A8E6CF"))
            Spacer()
            // Twitch connection indicator
            if twitchBridge.isConnected {
                HStack(spacing: 3) {
                    Circle().fill(Color(hex: "#9146FF")).frame(width: 5, height: 5)
                    Text("TWITCH")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundColor(Color(hex: "#9146FF"))
                }
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color(hex: "#9146FF").opacity(0.12))
                .cornerRadius(3)
            }
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
                    ForEach(timeline) { item in
                        switch item {
                        case .crew(let msg):
                            ChatBubble(message: msg)
                                .id(item.id)
                        case .viewer(let msg):
                            TwitchBubble(message: msg)
                                .id(item.id)
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: timeline.count) { _ in
                if let last = timeline.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - ChatBubble (crew)
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

// MARK: - TwitchBubble (viewer)
struct TwitchBubble: View {
    let message: ViewerMessage

    private let twitchPurple = Color(hex: "#9146FF")

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Twitch purple left border
            Rectangle()
                .fill(twitchPurple)
                .frame(width: 2)
                .cornerRadius(1)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("📺")
                        .font(.system(size: 10))
                    Text(message.username)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(twitchPurple)
                    badgeRow
                    Spacer(minLength: 0)
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                }
                Text(message.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.80))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var badgeRow: some View {
        ForEach(message.badges, id: \.rawValue) { badge in
            Text(badge.label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(twitchPurple.opacity(0.9))
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(twitchPurple.opacity(0.15))
                .cornerRadius(2)
        }
    }
}

// MARK: - TwitchBadge display label
private extension TwitchBadge {
    var label: String {
        switch self {
        case .subscriber:  return "SUB"
        case .vip:         return "VIP"
        case .mod:         return "MOD"
        case .broadcaster: return "BC"
        }
    }
}
