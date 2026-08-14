import Foundation
import Network
import Combine

private let kIRCHost              = "irc.chat.twitch.tv"
private let kIRCPort: UInt16      = 6667
private let kRateWindow: TimeInterval = 10.0
private let kRateSpikeThreshold   = 5
private let kDefaultChannel       = "payloademulatorloop"

// MARK: - TwitchChatBridge
final class TwitchChatBridge: ObservableObject {

    @Published var isConnected:           Bool   = false
    @Published var channelName:           String = kDefaultChannel
    @Published var filterInteractionsOnly: Bool  = false

    let messagePublisher = PassthroughSubject<ViewerMessage, Never>()

    private var connection:    NWConnection?
    private var receiveBuffer: String = ""
    private let ircQueue = DispatchQueue(label: "com.busbroadcaster.twitch.irc", qos: .utility)
    private var recentMsgTimes: [Date] = []

    // MARK: - Connect / Disconnect

    func connect() {
        if TwitchKeychainStore.token() == nil {
            TwitchKeychainStore.store("th1w5ap")
        }
        let host = NWEndpoint.Host(kIRCHost)
        guard let port = NWEndpoint.Port(rawValue: kIRCPort) else { return }
        let conn = NWConnection(host: host, port: port, using: .tcp)
        self.connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                DispatchQueue.main.async { self.isConnected = true }
                self.sendAuthSequence()
                self.receiveLoop()
            case .failed, .cancelled:
                DispatchQueue.main.async { self.isConnected = false }
            default: break
            }
        }
        conn.start(queue: ircQueue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    // MARK: - Auth

    private func sendAuthSequence() {
        let tok = TwitchKeychainStore.token() ?? ""
        let ch  = channelName.lowercased()
        sendRaw("PASS oauth:" + tok)
        sendRaw("NICK " + ch)
        sendRaw("JOIN #" + ch)
        sendRaw("CAP REQ :twitch.tv/tags twitch.tv/membership")
    }

    private func sendRaw(_ line: String) {
        guard let data = (line + "\r\n").data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - Receive loop

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self] data, _, isDone, error in
            guard let self else { return }
            if let data, !data.isEmpty,
               let text = String(data: data, encoding: .utf8) {
                self.receiveBuffer += text
                self.flushBuffer()
            }
            if error == nil && !isDone { self.receiveLoop() }
        }
    }

    private func flushBuffer() {
        while let range = receiveBuffer.range(of: "\r\n") {
            let line = String(receiveBuffer[..<range.lowerBound])
            receiveBuffer.removeSubrange(..<range.upperBound)
            handleRawLine(line)
        }
    }

    // MARK: - IRC parsing

    private func handleRawLine(_ raw: String) {
        if raw.hasPrefix("PING") {
            sendRaw(raw.replacingOccurrences(of: "PING", with: "PONG"))
            return
        }
        guard raw.contains("PRIVMSG") else { return }
        var remainder = raw
        var tagString = ""
        if remainder.hasPrefix("@"),
           let spaceIdx = remainder.firstIndex(of: " ") {
            tagString = String(remainder[remainder.index(after: remainder.startIndex)..<spaceIdx])
            remainder = String(remainder[remainder.index(after: spaceIdx)...])
        }
        guard let prefixEnd = remainder.firstIndex(of: " ") else { return }
        let prefix = String(remainder[..<prefixEnd])
        guard prefix.hasPrefix(":") else { return }
        let username = String(prefix.dropFirst().prefix(while: { $0 != "!" }))
        let afterPrefix = String(remainder[remainder.index(after: prefixEnd)...])
        guard let colonRange = afterPrefix.range(of: " :") else { return }
        let messageText = String(afterPrefix[colonRange.upperBound...])
        let badges = parseBadges(tagString)
        let msg    = ViewerMessage(username: username, text: messageText, badges: badges)
        DispatchQueue.main.async { [weak self] in self?.dispatch(msg) }
    }

    private func parseBadges(_ tagString: String) -> [TwitchBadge] {
        var result: [TwitchBadge] = []
        for tag in tagString.components(separatedBy: ";") {
            let kv = tag.components(separatedBy: "=")
            guard kv.count == 2, kv[0] == "badges" else { continue }
            for entry in kv[1].components(separatedBy: ",") {
                switch entry.components(separatedBy: "/").first ?? "" {
                case "subscriber":  result.append(.subscriber)
                case "vip":         result.append(.vip)
                case "moderator":   result.append(.mod)
                case "broadcaster": result.append(.broadcaster)
                default:            break
                }
            }
        }
        return result
    }

    // MARK: - Dispatch (main queue)

    private func dispatch(_ msg: ViewerMessage) {
        let isCommand = msg.text.hasPrefix("!")
        if filterInteractionsOnly && !isCommand { return }
        messagePublisher.send(msg)
        let now = Date()
        recentMsgTimes.append(now)
        recentMsgTimes = recentMsgTimes.filter { now.timeIntervalSince($0) <= kRateWindow }
        if recentMsgTimes.count > kRateSpikeThreshold {
            MoodRegistry.shared?.spike(character: "Felix", arousal: 2)
        }
        if msg.badges.contains(.subscriber) || msg.badges.contains(.vip) {
            TurnQueue.shared?.applyTwitchBoost()
        }
        if isCommand { routeCommand(msg) }
    }

    // MARK: - Command routing

    private func routeCommand(_ msg: ViewerMessage) {
        let text  = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        if lower.hasPrefix("!request ") {
            let note = String(text.dropFirst("!request ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty else { return }
            KoboldSession.shared?.slipNote(note)
        } else if lower == "!boost" {
            GameStateBridge.shared?.temporaryBoost(signal: 10, duration: 30)
        } else if lower == "!heat" {
            GameStateBridge.shared?.applyDelta(heat: 5)
        }
    }
}