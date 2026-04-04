import Foundation
import Combine

// MARK: - MoodRegistry
//
// Observable store for all character MoodStates.
// Owned by TurnQueue — exposed as @EnvironmentObject for views.
//
// Two update paths:
//  1. updateFromGameState(_:koboldActive:) — called on every GameState tick.
//     Adjusts valence, arousal, calm, connection, load from game pressures.
//  2. processSpeech(characterName:text:) — called after each apfel response.
//     Runs BehavioralAnalyzer on the text and blends results into the mood.

class MoodRegistry: ObservableObject {

    @Published var moods: [String: MoodState] = MoodRegistry.defaults

    static let defaults: [String: MoodState] = [
        "Dolores":          .dolores,
        "Soren":            .soren,
        "Priya":            .priya,
        "Marcus":           .marcus,
        "Yael":             .yael,
        "Felix":            .felix,
        "Detective Morrow": .detective,
        "Prophet":          .prophet,
        "Nadia":            .nadia,
        "Kobold":           .kobold,
    ]

    func mood(for name: String) -> MoodState { moods[name] ?? MoodState() }

    // MARK: - Post-speech behavioral update

    /// Called by TurnQueue after each apfel stream completes.
    /// Runs BehavioralAnalyzer on the finished text and updates the character's mood.
    func processSpeech(characterName: String, text: String) {
        var m = mood(for: characterName)
        let signals = BehavioralAnalyzer.analyze(text)
        BehavioralAnalyzer.apply(signals, to: &m)
        m.emotion = inferEmotion(from: m)
        moods[characterName] = m
    }

    // MARK: - Game-state-driven updates

    /// Called by TurnQueue on every GameState change.
    /// Adjusts valence, arousal, calm, connection, load per character.
    func updateFromGameState(_ state: GameState, koboldActive: Bool = false) {
        patch("Dolores")          { m in
            m.valence    = state.heatLevel == .critical ? -3 : state.heatLevel == .high ? -1 : 1
            m.arousal    = min(10, state.heat / 10.0)
            m.load       = min(10, state.heat / 10.0)
            m.connection = 7.0
        }
        patch("Soren")            { m in
            m.valence    = state.signal > 60 ? (state.currentSong != nil ? 4 : 2) : -2
            m.arousal    = state.signal > 70 ? 8 : state.signal < 25 ? 1 : 5
            m.calm       = state.signal > 60 ? 6 : 3
            m.connection = state.currentSong != nil ? 9 : 5
        }
        patch("Priya")            { m in
            m.load       = max(0, 10 - state.parts / 10.0)
            m.arousal    = state.parts < 30 ? 8 : state.signal < 30 ? 7 : 5
            m.valence    = state.parts > 80 && state.signal > 70 ? 2 : -1
            m.calm       = state.parts > 60 ? 6 : 3
        }
        patch("Marcus")           { m in
            m.arousal    = state.isDetectiveThreat ? 8 : state.heatLevel == .high ? 6 : 2
            m.calm       = state.isDetectiveThreat ? 2 : state.heatLevel == .high ? 4 : 9
            m.valence    = state.isDetectiveThreat ? -4 : 0
            m.connection = 4.0
        }
        patch("Yael")             { m in
            m.load       = max(0, 10 - state.parts / 10.0)
            m.arousal    = state.parts < 25 ? 9 : state.parts < 50 ? 6 : 4
            m.calm       = state.parts > 75 ? 7 : 4
            m.valence    = state.parts > 80 ? 2 : -1
        }
        patch("Felix")            { m in
            m.arousal    = state.isDetectiveThreat ? 9 : state.heatLevel == .high ? 8 : 6
            m.calm       = state.isDetectiveThreat ? 1 : state.heatLevel == .high ? 2 : 5
            m.valence    = state.heatLevel == .low ? 0 : -1.5
        }
        patch("Detective Morrow") { m in
            m.arousal    = state.heat > 90 ? 9 : 6
            m.calm       = state.heat > 90 ? 1 : 4
            m.valence    = -2.0
            m.connection = 3.0
        }
        patch("Prophet")          { m in
            m.arousal    = state.heatLevel == .critical ? 1 : state.signal > 60 ? 4 : 3
            m.calm       = state.heatLevel == .critical ? 2 : 7
            m.connection = state.signal > 60 ? 8 : 5
            m.valence    = state.heatLevel == .critical ? -1 : 1
        }
        patch("Nadia")            { m in
            m.arousal    = koboldActive ? 6 : state.heatLevel == .critical ? 1 : 4
            m.calm       = koboldActive ? 5 : state.heatLevel == .critical ? 2 : 7
            m.connection = koboldActive ? 7 : 6
            m.valence    = koboldActive ? 1 : 0
        }
        patch("Kobold")           { m in
            m.arousal    = koboldActive ? min(10, m.arousal + 1) : max(0, m.arousal - 0.5)
            m.connection = koboldActive ? 4 : 2
        }
    }

    // MARK: - TurnQueue weighting helpers

    /// Weight multiplier for TurnQueue.pickNextSpeaker() — driven by SI, arousal, connection.
    func speakWeight(for name: String) -> Double {
        let m  = mood(for: name)
        var w  = 1.0
        let si = m.stressIndex
        // SI > 7 (red):  urgent, interrupts more
        if si > 7      { w *= 1.70 }
        // SI < 3 (green): calm, lets others speak
        else if si < 3 { w *= 0.60 }
        // High arousal → speaks now
        if m.arousal > 8 { w *= 1.40 }
        // Disconnected → goes quiet for a turn
        if m.connection < 3 { w *= 0.10 }
        return max(w, 0.05)   // floor so fully withdrawn chars can still surface
    }

    /// True when calm < 3 — character sends fragmented/short messages.
    /// TurnQueue injects a prompt hint when this fires.
    func isFragmented(name: String) -> Bool { mood(for: name).calm < 3 }

    // MARK: - Private helpers

    private func patch(_ name: String, _ block: (inout MoodState) -> Void) {
        var m = mood(for: name)
        block(&m)
        m.emotion = inferEmotion(from: m)
        moods[name] = m
    }

    /// Infer a one-word emotion label from the current dimensional state.
    private func inferEmotion(from m: MoodState) -> String {
        let si = m.stressIndex
        if m.valence < -3              { return "distressed" }
        if si > 8                      { return "overwhelmed" }
        if si > 6                      { return "tense" }
        if m.arousal > 8 && m.valence > 2 { return "charged" }
        if m.arousal > 7               { return "agitated" }
        if m.valence > 3               { return "elated" }
        if si < 2 && m.arousal < 3     { return "serene" }
        if si < 3                      { return "calm" }
        if m.valence > 1               { return "composed" }
        if m.arousal < 3               { return "detached" }
        if m.connection < 3            { return "withdrawn" }
        if m.arousal > 5               { return "focused" }
        return "neutral"
    }
}
