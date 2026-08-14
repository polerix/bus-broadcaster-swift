import Foundation
import AVFoundation

/// BusPlayer — the show must go on.
///
/// Always playing something: video/movie files from GrimoireVol2, or a
/// generated ambient tone when the drive isn't mounted. Automatically
/// ducks volume when TTS fires, restores after.
///
/// Scanning and selection mirrors GrimoireLibrary.randomVideoURL() but
/// maintains a shuffled queue so tracks don't repeat until the pool is
/// exhausted (like a real broadcast schedule, not shuffle-with-repeats).
final class BusPlayer: NSObject, ObservableObject {
    static let shared = BusPlayer()

    @Published var isPlaying = false
    @Published var currentTitle: String = ""

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var queue: [URL] = []
    private var queueIndex = 0
    private var endObserver: Any?

    // Volume state
    private var normalVolume: Float = 0.35   // background level during broadcast
    private var duckedVolume:  Float = 0.07   // under TTS speech
    private var isDucked = false

    private override init() {
        super.init()
        buildQueue()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    // MARK: - Public

    func start() {
        guard !isPlaying else { return }
        if queue.isEmpty { buildQueue() }
        if queue.isEmpty { startAmbientTone(); return }
        playCurrentItem()
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentTitle = ""
    }

    /// Fade volume down under TTS — call when speech begins
    func duck() {
        guard !isDucked else { return }
        isDucked = true
        fadeVolume(to: duckedVolume, duration: 0.4)
    }

    /// Restore volume after TTS — call when speech ends
    func unduck() {
        guard isDucked else { return }
        isDucked = false
        fadeVolume(to: normalVolume, duration: 1.2)
    }

    func skipToNext() {
        advance()
    }

    // MARK: - Queue

    private func buildQueue() {
        var urls: [URL] = []
        let roots: [String] = [
            "/Volumes/GrimoireVol2/Movies",
            "/Volumes/GrimoireVol2/Shows",
        ]
        let exts = Set(["mkv","mp4","mov","avi","m4v","mp3","flac","aiff","wav","m4a"])
        let fm = FileManager.default
        for root in roots {
            guard fm.fileExists(atPath: root) else { continue }
            // Top-level files
            if let items = try? fm.contentsOfDirectory(atPath: root) {
                for item in items {
                    let url = URL(fileURLWithPath: root).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    fm.fileExists(atPath: url.path, isDirectory: &isDir)
                    if isDir.boolValue {
                        // One level deep into subdirectories
                        if let sub = try? fm.contentsOfDirectory(atPath: url.path) {
                            for f in sub {
                                let furl = url.appendingPathComponent(f)
                                if exts.contains(furl.pathExtension.lowercased()) {
                                    urls.append(furl)
                                }
                            }
                        }
                    } else if exts.contains(url.pathExtension.lowercased()) {
                        urls.append(url)
                    }
                }
            }
        }
        queue = urls.shuffled()
        queueIndex = 0
        if !queue.isEmpty {
            print("[BusPlayer] queue built: \(queue.count) tracks")
        }
    }

    private func playCurrentItem() {
        if queueIndex >= queue.count {
            // Exhausted — reshuffle and restart
            queue.shuffle()
            queueIndex = 0
            if queue.isEmpty { startAmbientTone(); return }
        }
        let url = queue[queueIndex]
        let item = AVPlayerItem(url: url)
        playerItem = item

        if let existing = player {
            existing.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        player?.volume = isDucked ? duckedVolume : normalVolume
        player?.play()
        isPlaying = true
        currentTitle = url.deletingPathExtension().lastPathComponent
        print("[BusPlayer] now playing: \(currentTitle)")
    }

    private func advance() {
        queueIndex += 1
        playCurrentItem()
    }

    @objc private func itemDidEnd(_ note: Notification) {
        guard let ended = note.object as? AVPlayerItem,
              ended === playerItem else { return }
        DispatchQueue.main.async { self.advance() }
    }

    // MARK: - Ambient fallback (no drive)

    private var toneEngine: AVAudioEngine?
    private var toneNode: AVAudioPlayerNode?

    private func startAmbientTone() {
        // 40Hz sub-bass drone — the hum of the bus engine
        let engine = AVAudioEngine()
        let node   = AVAudioPlayerNode()
        engine.attach(node)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        let frames: AVAudioFrameCount = 44100 * 4   // 4s loop
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return }
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / 44100.0
            // Layered: 40Hz fundamental + 80Hz + 120Hz + gentle noise
            let f1 = 0.08 * sin(2 * Double.pi * 40  * t)
            let f2 = 0.04 * sin(2 * Double.pi * 80  * t)
            let f3 = 0.02 * sin(2 * Double.pi * 120 * t)
            let noise = 0.01 * Double.random(in: -1...1)
            data[i] = Float(f1 + f2 + f3 + noise)
        }
        try? engine.start()
        node.scheduleBuffer(buf, at: nil, options: .loops)
        node.play()
        toneEngine = engine
        toneNode   = node
        isPlaying  = true
        currentTitle = "〜 ambient 〜"
        print("[BusPlayer] no GrimoireVol2 — playing ambient tone")
    }

    // MARK: - Volume fade

    private func fadeVolume(to target: Float, duration: Double) {
        guard let p = player else { return }
        let steps = 20
        let interval = duration / Double(steps)
        let start = p.volume
        let delta = (target - start) / Float(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                p.volume = start + delta * Float(i)
            }
        }
    }
}
