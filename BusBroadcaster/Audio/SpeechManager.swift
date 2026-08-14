import Foundation
import AVFoundation

/// SpeechManager — routes TTS through bustts-server (piper, local ONNX).
/// Falls back to AVSpeechSynthesizer if the server is not reachable.
///
/// bustts-server runs on 127.0.0.1:7331. It is launched by AppDelegate
/// on startup and kept alive for the session. After warm-up (~8s) all
/// voices are sub-300ms per phrase.
final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = SpeechManager()

    private let serverURL = URL(string: "http://127.0.0.1:7331/speak")!
    private let healthURL = URL(string: "http://127.0.0.1:7331/health")!
    private let session   = URLSession(configuration: .ephemeral)

    // Fallback synth (used when bustts-server is not reachable)
    private let synth = AVSpeechSynthesizer()
    private var serverAvailable = false

    // Audio player for piper WAV output
    private var player: AVAudioPlayer?
    // Serialise synthesis — one phrase at a time
    private let queue = DispatchQueue(label: "com.bus.tts", qos: .userInitiated)
    private var isSpeaking = false

    // Pre-synthesis cache: (character+textHash) → URL of WAV on disk
    // Populated during Governor drain window; consumed instantly by speak().
    private var preCache: [String: URL] = [:]
    private let cacheLock = NSLock()

    // AVSpeech fallback voice map
    private let fallbackVoices: [String: (name: String, rate: Float, pitch: Float)] = [
        "Dolores":          ("Samantha",  0.52, 1.1),
        "Soren":            ("Fred",      0.40, 0.9),
        "Priya":            ("Moira",     0.50, 1.05),
        "Marcus":           ("Daniel",    0.38, 0.85),
        "Yael":             ("Tessa",     0.48, 1.0),
        "Felix":            ("Junior",    0.58, 1.15),
        "Detective Morrow": ("Bad News",  0.36, 0.8),
        "Prophet":          ("Zarvox",    0.33, 0.75),
        "Nadia":            ("Karen",     0.50, 1.0),
        "Kobold":           ("Wobble",    0.42, 0.95),
    ]

    override init() {
        super.init()
        synth.delegate = self
        checkServerHealth()
    }

    // MARK: - Public

    /// Pre-synthesise text during the Governor drain window.
    /// Call this when generationComplete fires (full text known, drain still running).
    /// By the time speak() is called the WAV will be ready — near-zero latency playback.
    func preSynthesize(_ text: String, as character: String) {
        guard serverAvailable else { return }
        let cleaned = stripMarkup(text)
        guard !cleaned.isEmpty else { return }
        let key = cacheKey(character, cleaned)
        cacheLock.lock()
        let alreadyCached = preCache[key] != nil
        cacheLock.unlock()
        guard !alreadyCached else { return }

        queue.async { [weak self] in
            guard let self else { return }
            var req = URLRequest(url: self.serverURL, timeoutInterval: 12)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "character": character, "text": cleaned
            ])
            let sem = DispatchSemaphore(value: 0)
            self.session.dataTask(with: req) { [weak self] data, _, _ in
                defer { sem.signal() }
                guard let self, let data, data.count > 44 else { return }
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("bustts_pre_\(UUID().uuidString).wav")
                try? data.write(to: tmp)
                self.cacheLock.lock()
                self.preCache[key] = tmp
                self.cacheLock.unlock()
            }.resume()
            sem.wait()
        }
    }

    func speak(_ text: String, as character: String, isInternal: Bool = false) {
        let cleaned = stripMarkup(text)
        guard !cleaned.isEmpty else { return }

        if serverAvailable {
            // Check pre-synthesis cache first
            let key = cacheKey(character, cleaned)
            cacheLock.lock()
            let cached = preCache.removeValue(forKey: key)
            cacheLock.unlock()

            if let url = cached {
                // Pre-rendered: play immediately with subtle freshness variation
                DispatchQueue.main.async { self.playWAV(at: url, varyRate: true, isInternal: isInternal) }
            } else {
                speakViaPiper(cleaned, character: character, isInternal: isInternal)
            }
        } else {
            speakViaAV(cleaned, character: character, isInternal: isInternal)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
        // Clear pre-synthesis cache
        cacheLock.lock()
        let urls = Array(preCache.values)
        preCache.removeAll()
        cacheLock.unlock()
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private func cacheKey(_ character: String, _ text: String) -> String {
        "\(character):\(text.hashValue)"
    }

    // MARK: - bustts-server path

    private func speakViaPiper(_ text: String, character: String, isInternal: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            var req = URLRequest(url: self.serverURL, timeoutInterval: 8)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "character": character, "text": text
            ])

            let sem = DispatchSemaphore(value: 0)
            self.session.dataTask(with: req) { [weak self] data, resp, err in
                defer { sem.signal() }
                guard let self else { return }
                if let err {
                    print("[SpeechManager] piper error: \(err) — falling back")
                    self.serverAvailable = false
                    self.speakViaAV(text, character: character, isInternal: isInternal)
                    return
                }
                guard let data, data.count > 44 else { return } // empty WAV = silence OK
                // Write to temp file and play
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("bus_tts_\(UUID().uuidString).wav")
                do {
                    try data.write(to: tmp)
                    DispatchQueue.main.async {
                        self.playWAV(at: tmp, isInternal: isInternal)
                    }
                } catch {
                    print("[SpeechManager] WAV write error: \(error)")
                }
            }.resume()
            sem.wait()
        }
    }

    private func playWAV(at url: URL, varyRate: Bool = false, isInternal: Bool) {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            if varyRate {
                // Subtle ±4% rate drift — same take never sounds identical twice
                p.enableRate = true
                p.rate = Float.random(in: 0.96...1.04)
            }
            player = p
            if !isInternal {
                BusPlayer.shared.duck()            // lower background audio ONLY for broadcast
            }
            p.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + p.duration + 0.3) {
                if !isInternal {
                    BusPlayer.shared.unduck()      // restore after speech ONLY for broadcast
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + p.duration + 1) {
                try? FileManager.default.removeItem(at: url)
            }
        } catch {
            print("[SpeechManager] AVAudioPlayer error: \(error)")
        }
    }

    // MARK: - AVSpeechSynthesizer fallback

    private func speakViaAV(_ text: String, character: String, isInternal: Bool) {
        let utt = AVSpeechUtterance(string: text)
        let info = fallbackVoices[character]
        if let info {
            utt.voice = AVSpeechSynthesisVoice.speechVoices()
                .first(where: { $0.name == info.name })
                ?? AVSpeechSynthesisVoice(language: "en-US")
            utt.rate        = info.rate
            utt.pitchMultiplier = info.pitch
        } else {
            utt.voice = AVSpeechSynthesisVoice(language: "en-US")
            utt.rate  = 0.48
        }
        utt.preUtteranceDelay  = 0.05
        utt.postUtteranceDelay = 0.1
        DispatchQueue.main.async {
            if !isInternal {
                BusPlayer.shared.duck()
            }
            self.synth.speak(utt)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        BusPlayer.shared.unduck()
    }

    // MARK: - Health check

    private func checkServerHealth() {
        session.dataTask(with: URLRequest(url: healthURL, timeoutInterval: 3)) { [weak self] data, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                self?.serverAvailable = ok
                if ok { print("[SpeechManager] piper server ✓") }
                else  { print("[SpeechManager] piper server not ready — using AVSpeech") }
            }
        }.resume()
    }

    /// Re-check after AppDelegate signals server is up
    func serverDidBecomeReady() {
        serverAvailable = true
        print("[SpeechManager] piper server ready signal received ✓")
    }

    // MARK: - Utility

    private func stripMarkup(_ text: String) -> String {
        // Remove [bracketed stage directions] and *emotes*
        var s = text
        s = s.replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\*.*?\\*",  with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
