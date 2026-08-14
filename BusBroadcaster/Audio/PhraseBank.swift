import Foundation

/// PhraseBank — pre-renders common station phrases at startup.
///
/// Like the brain's predictive firing, we synthesise likely-to-be-used
/// phrases before they're needed. On recall, a fresh copy is made with
/// subtle rate variation so no two plays sound identical.
///
/// Phrases are grouped by character and category. TurnQueue or
/// BroadcastWindowView can call PhraseBank.shared.play(category:character:)
/// to get instant, natural-sounding audio.
final class PhraseBank {
    static let shared = PhraseBank()

    // category → character → [phrase variants]
    static let phrases: [String: [String: [String]]] = [

        "stationID": [
            "Dolores": [
                "BusBroadcaster. Transmission is resistance.",
                "You're on BusBroadcaster. We keep moving.",
                "This is BusBroadcaster. Stay with us.",
                "BusBroadcaster. Signal holds.",
            ],
            "Felix": [
                "BusBroadcaster — yeah, we're still here!",
                "You found us. BusBroadcaster, live from wherever we are.",
            ],
            "Prophet": [
                "The signal finds you. BusBroadcaster.",
                "We are the frequency between stations. BusBroadcaster.",
            ],
        ],

        "segueIn": [
            "Dolores": [
                "Coming up next.",
                "Next on the schedule.",
                "Standby.",
                "Up next.",
            ],
            "Felix": [
                "Okay okay, next up —",
                "Right, so —",
                "Hold on, this is good.",
            ],
            "Soren": [
                "Something else now.",
                "Let this one in.",
            ],
        ],

        "segueOut": [
            "Dolores": [
                "That was the last segment.",
                "Moving on.",
                "Filed.",
            ],
            "Felix": [
                "Okay, yeah. Anyway.",
                "Right. Moving.",
            ],
            "Nadia": [
                "Done.",
                "Next.",
            ],
        ],

        "signalWeak": [
            "Dolores": [
                "Signal degrading. Hold position.",
                "We're losing signal. Priya, check the antenna.",
                "Signal weak. Still transmitting.",
            ],
            "Priya": [
                "Signal drop detected. Rerouting.",
                "Interference on the band. Compensating.",
            ],
        ],

        "signalStrong": [
            "Dolores": [
                "Signal is clean. We are loud and clear.",
                "Full signal. Broadcast continues.",
            ],
            "Felix": [
                "We are fully live right now. Clean signal.",
            ],
        ],

        "fuelLow": [
            "Marcus": [
                "Fuel's down. Plan accordingly.",
                "We should talk about the fuel situation.",
                "Running lean. Not ideal.",
            ],
            "Yael": [
                "Fuel warning. Someone call it in.",
                "Low fuel. Noted.",
            ],
        ],

        "threatNear": [
            "Dolores": [
                "Eyes up. Non-essential chatter stops now.",
                "We have company. Quiet.",
            ],
            "Detective Morrow": [
                "I know this route. And I know where it ends.",
                "You can't broadcast forever.",
            ],
        ],

        "koboldAppears": [
            "Kobold": [
                "I was here before you arrived.",
                "Something has been left for you.",
                "The cache is not where you think.",
                "I remember things that haven't happened yet.",
            ],
        ],
    ]

    private let speech = SpeechManager.shared
    // category:character → index of last played (for round-robin freshness)
    private var lastPlayed: [String: Int] = [:]
    private let lock = NSLock()

    private init() {}

    /// Pre-synthesise all phrases for priority characters at startup.
    func warmUp() {
        let priority = ["Dolores", "Felix", "Priya", "Marcus"]
        let priorityCategories = ["stationID", "segueIn", "segueOut", "signalWeak", "fuelLow"]
        for cat in priorityCategories {
            guard let byChar = PhraseBank.phrases[cat] else { continue }
            for char in priority {
                guard let variants = byChar[char] else { continue }
                for phrase in variants {
                    speech.preSynthesize(phrase, as: char)
                }
            }
        }
    }

    /// Play a phrase from a category, spoken by character.
    /// Cycles through variants round-robin; each play gets ±4% rate drift.
    func play(category: String, character: String) {
        guard let variants = PhraseBank.phrases[category]?[character],
              !variants.isEmpty else { return }
        let key = "\(category):\(character)"
        lock.lock()
        let idx = (lastPlayed[key, default: -1] + 1) % variants.count
        lastPlayed[key] = idx
        lock.unlock()
        let phrase = variants[idx]
        speech.speak(phrase, as: character)
    }

    /// Random variant from category/character — for non-sequential use.
    func playRandom(category: String, character: String) {
        guard let variants = PhraseBank.phrases[category]?[character],
              !variants.isEmpty else { return }
        speech.speak(variants.randomElement()!, as: character)
    }
}
