import SwiftUI

// MARK: - soul-forge EmoBar — MoodState
//
// 6-dimensional affective state for each character sleeve.
// Source: polerix/soul-forge — "Souls are the liquid identity
// that flows through the sleeves."
//
// Dimensions:
//   emotion    — one-word label (self-reported by character logic)
//   valence    — −5.0 (very negative) → +5.0 (very positive)
//   arousal    —  0 (inert) → 10 (maximally activated)
//   calm       —  0 (agitated) → 10 (fully composed)
//   connection —  0 (disengaged) → 10 (deeply aligned)
//   load       —  0 (trivial) → 10 (maximum cognitive complexity)

struct MoodState {
    var emotion:    String = "neutral"
    var valence:    Double = 0.0     // −5 to +5
    var arousal:    Double = 3.0     // 0–10
    var calm:       Double = 7.0     // 0–10
    var connection: Double = 5.0     // 0–10
    var load:       Double = 3.0     // 0–10

    /// Set by BehavioralAnalyzer when text signals diverge from self-report
    var isDivergent: Bool = false

    // MARK: - Derived metrics

    /// Stress Index — composite pressure [0–10]
    /// Formula: ((10 - calm) + arousal + (5 - valence)) / 3
    var stressIndex: Double {
        ((10 - calm) + arousal + (5 - valence)) / 3.0
    }

    /// SI-keyed color (soul-forge EmoBar palette)
    var stressColor: Color {
        switch stressIndex {
        case ..<3: return Color(hex: "#00ffaa")   // green  — low stress
        case ..<5: return Color(hex: "#00ccff")   // cyan   — mild
        case ..<7: return Color(hex: "#ffaa00")   // amber  — elevated
        default:   return Color(hex: "#ff4466")   // red    — critical
        }
    }
}

// MARK: - Personality-appropriate defaults per character sleeve

extension MoodState {
    /// Dolores: composed dispatch operator — calm, moderate arousal
    static var dolores:   MoodState { MoodState(emotion: "composed",   valence:  1.0, arousal: 4.0, calm: 8.0, connection: 7.0, load: 5.0) }
    /// Soren: elated DJ — high arousal, positive valence, on-air energy
    static var soren:     MoodState { MoodState(emotion: "elated",     valence:  4.0, arousal: 8.0, calm: 5.0, connection: 7.0, load: 4.0) }
    /// Priya: focused engineer — high load, moderate calm
    static var priya:     MoodState { MoodState(emotion: "focused",    valence:  1.0, arousal: 6.0, calm: 5.0, connection: 6.0, load: 8.0) }
    /// Marcus: detached driver — extremely calm, low arousal
    static var marcus:    MoodState { MoodState(emotion: "detached",   valence:  0.0, arousal: 2.0, calm: 9.0, connection: 4.0, load: 3.0) }
    /// Yael: methodical mechanic — high load, steady calm
    static var yael:      MoodState { MoodState(emotion: "methodical", valence:  1.0, arousal: 5.0, calm: 6.0, connection: 6.0, load: 7.0) }
    /// Felix: anxious lookout — high arousal, low calm, watching everything
    static var felix:     MoodState { MoodState(emotion: "anxious",    valence: -1.0, arousal: 7.0, calm: 3.0, connection: 5.0, load: 5.0) }
    /// Detective Morrow: suspicious threat — negative valence, low connection
    static var detective: MoodState { MoodState(emotion: "suspicious", valence: -2.0, arousal: 6.0, calm: 4.0, connection: 3.0, load: 6.0) }
    /// Prophet: prophetic vagrant — low arousal, high connection
    static var prophet:   MoodState { MoodState(emotion: "prophetic",  valence:  1.0, arousal: 3.0, calm: 7.0, connection: 8.0, load: 5.0) }
    /// Nadia: watchful vendor — balanced, watchful baseline
    static var nadia:     MoodState { MoodState(emotion: "watchful",   valence:  0.0, arousal: 4.0, calm: 7.0, connection: 6.0, load: 4.0) }
    /// KoboldAI: cryptic entity — negative valence, low connection, high load
    static var kobold:    MoodState { MoodState(emotion: "cryptic",    valence: -2.0, arousal: 5.0, calm: 5.0, connection: 3.0, load: 7.0) }
}
