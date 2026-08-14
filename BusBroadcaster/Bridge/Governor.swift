import Foundation

/// The Governor — controls how fast text appears on screen and how long to wait
/// before the next speaker is allowed to begin. Named after the centrifugal
/// steam governor: when the system runs too fast, it throttles back.
///
/// Two rates per character:
///   readingRate  — characters/sec displayed to screen (typewriter effect)
///   speakingWPM  — estimated TTS words/minute, used to calculate post-speech pause
///
final class Governor {

    // MARK: - Per-character display speed (chars/sec → reading WPM = rate * 60 / 5)
    // Felix at 22 c/s ≈ 264 WPM  (caffeine, young, anxious)
    // Marcus at 6 c/s  ≈  72 WPM  (deliberate, each word costs something)
    // Kobold at 4 c/s  ≈  48 WPM  (glitching, wrong)
    static let readingRates: [String: Double] = [
        "Dolores":          16.0,   // ~192 WPM — clipped dispatch
        "Soren":             9.0,   // ~108 WPM — dreamy, drifting
        "Priya":            15.0,   // ~180 WPM — precise
        "Marcus":            6.0,   // ~ 72 WPM — weighted silences
        "Yael":             12.0,   // ~144 WPM — direct, no poetry
        "Felix":            22.0,   // ~264 WPM — wired on caffeine
        "Detective Morrow":  6.0,   // ~ 72 WPM — ominous pause
        "Prophet":           5.0,   // ~ 60 WPM — each word deliberate
        "Nadia":            12.0,   // ~144 WPM — sharp
        "Kobold":            4.0,   // ~ 48 WPM — glitch-paced
    ]

    // MARK: - TTS speaking rate (WPM). Used to estimate how long the voice
    // will take so the next speaker doesn't fire while someone is still talking.
    static let speakingWPM: [String: Double] = [
        "Dolores":          155.0,
        "Soren":            120.0,
        "Priya":            148.0,
        "Marcus":           108.0,
        "Yael":             138.0,
        "Felix":            175.0,
        "Detective Morrow": 105.0,
        "Prophet":           95.0,
        "Nadia":            140.0,
        "Kobold":            80.0,
    ]

    // MARK: - State
    private let character: String
    private let rate: Double          // chars/sec to display
    private var buffer:   String = "" // incoming tokens queue here
    private var accumulator: Double = 0.0  // fractional chars owed
    private var isGenerationDone = false
    private var drainTimer: Timer?

    // Callbacks — all called on main thread
    private let onChar:      (String) -> Void   // one character at a time to screen
    private let onTextKnown: (String) -> Void   // full text known (gen done, still draining)
    private let onDrained:   (String) -> Void   // drain complete — safe to play audio
    private var fullText:    String = ""        // accumulates as chars are emitted
    private var textKnownFired = false

    init(character: String,
         onChar:      @escaping (String) -> Void,
         onTextKnown: @escaping (String) -> Void = { _ in },
         onDrained:   @escaping (String) -> Void) {
        self.character    = character
        self.rate         = Governor.readingRates[character] ?? 12.0
        self.onChar       = onChar
        self.onTextKnown  = onTextKnown
        self.onDrained    = onDrained
    }

    /// Feed a token from apfel into the buffer.
    func feed(_ token: String) {
        buffer += token
        if drainTimer == nil { startDraining() }
    }

    /// Called when apfel's onComplete fires — generation is done, drain the rest.
    /// Fires onTextKnown immediately with the full buffered text so the caller
    /// can kick off TTS pre-synthesis while the drain timer is still running.
    func generationComplete() {
        isGenerationDone = true
        // Fire onTextKnown once — full text = already-drained chars + remaining buffer
        if !textKnownFired {
            textKnownFired = true
            onTextKnown(fullText + buffer)
        }
        if drainTimer == nil && !buffer.isEmpty { startDraining() }
        else if drainTimer == nil && buffer.isEmpty { finish() }
    }

    func cancel() {
        drainTimer?.invalidate()
        drainTimer = nil
    }

    // MARK: - Internal

    private func startDraining() {
        // Tick every 40ms (25 fps). Each tick we drain `rate * 0.040` chars.
        // Use .common mode so the timer fires even while the run loop is in
        // .eventTracking (scrolling, mouse tracking) — otherwise display stalls.
        let t = Timer(timeInterval: 0.040, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        drainTimer = t
    }

    private func tick() {
        accumulator += rate * 0.040

        while accumulator >= 1.0 && !buffer.isEmpty {
            let char = String(buffer.removeFirst())
            fullText += char
            onChar(char)
            accumulator -= 1.0
        }

        // Done draining AND generation is finished
        if buffer.isEmpty && isGenerationDone {
            drainTimer?.invalidate()
            drainTimer = nil
            finish()
        }
    }

    private func finish() {
        onDrained(fullText)
    }

    // MARK: - Helpers

    /// Estimated seconds before the next speaker should be allowed to start.
    /// = time for TTS to finish + a breath gap.
    static func nextSpeakerDelay(for character: String, text: String) -> Double {
        let words  = Double(text.split(separator: " ").count)
        let wpm    = speakingWPM[character] ?? 140.0
        let ttsSec = words / wpm * 60.0
        let breath = Double.random(in: 1.5...3.5)   // natural pause between speakers
        return max(3.0, ttsSec + breath)
    }
}
