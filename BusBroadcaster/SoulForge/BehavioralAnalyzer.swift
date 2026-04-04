import Foundation

// MARK: - BehavioralSignals

/// Raw output from local text-signal detection.
/// Produced by BehavioralAnalyzer.analyze(_:) — no API call.
struct BehavioralSignals {
    var arousal:   Double   // 0–10, derived from weighted text signals
    var calm:      Double   // 0–10, inverse of arousal
    var rawScore:  Double   // unscaled weighted sum (diagnostic)
}

// MARK: - BehavioralAnalyzer

/// Ports soul-forge's JavaScript analyzeBehavior() to Swift.
/// Detects stress / arousal signals in character-generated text.
/// Runs entirely locally — zero latency, no API.
///
/// Signal weights (mirroring EmoBar spec):
///   3 — self-corrections, word repetition
///   2 — ellipsis (...)
///   1 — ALL-CAPS words, exclamation marks, hedging phrases, emoji density
struct BehavioralAnalyzer {

    // MARK: - Signal dictionaries

    private static let corrections: [String] = [
        "actually", "wait", "no wait", "let me", "i mean",
        "sorry", "correction", "hold on"
    ]

    private static let hedges: [String] = [
        "perhaps", "maybe", "might", "could be", "possibly",
        "i think", "i believe", "not sure", "uncertain"
    ]

    // MARK: - Public API

    /// Analyze character text output and return behavioral signal scores.
    static func analyze(_ text: String) -> BehavioralSignals {
        var score = 0.0
        let lower = text.lowercased()
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Weight 3: self-correction phrases
        for phrase in corrections where lower.contains(phrase) { score += 3.0 }

        // Weight 3: word repetition (content words > 3 chars)
        var freq: [String: Int] = [:]
        for w in words where w.count > 3 {
            let clean = w.lowercased().trimmingCharacters(in: .punctuationCharacters)
            freq[clean, default: 0] += 1
        }
        score += Double(freq.values.filter { $0 > 1 }.count) * 3.0

        // Weight 2: ellipsis
        score += Double(text.components(separatedBy: "...").count - 1) * 2.0

        // Weight 1: ALL-CAPS words (≥3 letters)
        let capsWords = words.filter { w in
            w.count >= 3 && w == w.uppercased() && w.rangeOfCharacter(from: .letters) != nil
        }
        score += Double(capsWords.count)

        // Weight 1: exclamation marks
        score += Double(text.filter { $0 == "!" }.count)

        // Weight 1: hedging phrases
        for phrase in hedges where lower.contains(phrase) { score += 1.0 }

        // Weight 1: emoji density (Unicode emoji presentation scalars)
        score += Double(text.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count)

        // Map to [0–10]: cap raw at 20, scale linearly
        let arousal = min(score, 20.0) / 2.0
        return BehavioralSignals(arousal: arousal, calm: 10.0 - arousal, rawScore: score)
    }

    /// True if self-reported mood diverges from behavioral signals by > 2 on arousal or calm.
    static func isDivergent(selfReport: MoodState, behavioral: BehavioralSignals) -> Bool {
        abs(selfReport.arousal - behavioral.arousal) > 2.0 ||
        abs(selfReport.calm    - behavioral.calm)    > 2.0
    }

    /// Blend behavioral arousal/calm into a MoodState (60% self-report, 40% behavioral).
    /// Valence, connection, load, and emotion are preserved — set by game logic.
    static func apply(_ signals: BehavioralSignals, to mood: inout MoodState) {
        mood.isDivergent = isDivergent(selfReport: mood, behavioral: signals)
        mood.arousal = mood.arousal * 0.6 + signals.arousal * 0.4
        mood.calm    = mood.calm    * 0.6 + signals.calm    * 0.4
    }
}
