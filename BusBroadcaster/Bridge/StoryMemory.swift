import Foundation

/// Keeps the crew from repeating themselves.
/// Tracks topics, recent speakers, and session arc — injected into every prompt.
final class StoryMemory {

    // MARK: - Deduplication

    /// Normalized hash of every phrase spoken this session.
    private var spokenHashes: Set<Int> = []

    // MARK: - Topic log

    private struct TopicEntry {
        let character: String
        let snippet:   String   // first ~60 chars of what was said
        let timestamp: Date
    }
    private var topicLog: [TopicEntry] = []
    private let maxTopics = 24  // rolling window

    // MARK: - Recent speaker ring

    private var recentSpeakers: [String] = []
    private let speakerWindowSize = 4

    // MARK: - Session arc

    private(set) var sessionSummary: String = ""
    private var totalTurns: Int = 0
    private let summaryRebuildInterval = 12   // rebuild summary every N turns

    // MARK: - Thread safety

    private let lock = NSLock()

    // MARK: - Record a completed turn

    func record(character: String, text: String) {
        lock.lock(); defer { lock.unlock() }

        totalTurns += 1

        // --- Deduplication hash ---
        let normalized = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        spokenHashes.insert(normalized.hashValue)

        // --- Topic log ---
        let snippet = String(text.prefix(70))
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first.map { $0.trimmingCharacters(in: .whitespaces) } ?? String(text.prefix(60))
        topicLog.append(TopicEntry(character: character, snippet: snippet, timestamp: Date()))
        if topicLog.count > maxTopics { topicLog.removeFirst() }

        // --- Speaker ring ---
        recentSpeakers.append(character)
        if recentSpeakers.count > speakerWindowSize { recentSpeakers.removeFirst() }

        // --- Periodic arc rebuild ---
        if totalTurns % summaryRebuildInterval == 0 {
            rebuildSummary()
        }
    }

    // MARK: - Duplicate detection

    func isProbablyDuplicate(_ text: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let normalized = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return spokenHashes.contains(normalized.hashValue)
    }

    // MARK: - Prompt context block

    /// Returns a compact block to prepend to each generation prompt.
    func contextBlock(for character: String) -> String {
        lock.lock(); defer { lock.unlock() }

        var lines: [String] = []

        // Session arc (after enough turns)
        if !sessionSummary.isEmpty {
            lines.append("[BROADCAST ARC: \(sessionSummary)]")
        }

        // Recent topics covered (avoid repeating)
        if topicLog.count >= 2 {
            let recent = topicLog.suffix(8)
                .map { "\($0.character): \($0.snippet)" }
                .joined(separator: " | ")
            lines.append("[COVERED RECENTLY: \(recent)]")
            lines.append("[Do NOT revisit topics already covered. Advance, react, or pivot.]")
        }

        // Speaker pressure — if this character spoke very recently
        let lastTwoSpeakers = recentSpeakers.suffix(2)
        if lastTwoSpeakers.contains(character) && (recentSpeakers.last != character || recentSpeakers.count == 1) {
            lines.append("[You spoke recently. Advance the story or react to someone else's thread — don't repeat your last point.]")
        }

        // Prevent consecutive domination
        if recentSpeakers.filter({ $0 == character }).count >= 2 {
            lines.append("[Other crew members need air time. Keep this brief so someone else can respond.]")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Clear (new session)

    func reset() {
        lock.lock(); defer { lock.unlock() }
        spokenHashes.removeAll()
        topicLog.removeAll()
        recentSpeakers.removeAll()
        sessionSummary = ""
        totalTurns = 0
    }

    // MARK: - Private

    private func rebuildSummary() {
        guard topicLog.count >= 4 else { return }

        // Cluster by character to find dominant threads
        var characterLines: [String: [String]] = [:]
        for entry in topicLog {
            characterLines[entry.character, default: []].append(entry.snippet)
        }

        // One-liner per character: "Felix: signal scans, Reddit findings"
        let arcs = characterLines.compactMap { (name, snippets) -> String? in
            guard !snippets.isEmpty else { return nil }
            let condensed = snippets.prefix(3).joined(separator: ", ")
            return "\(name): \(condensed)"
        }.joined(separator: "; ")

        sessionSummary = String(arcs.prefix(300))  // cap at 300 chars
    }
}
