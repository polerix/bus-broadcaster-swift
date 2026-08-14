import SwiftUI
import AVKit

/// Wraps AVPlayerView for local file preview in the work panel.
/// Plays muted, no controls, loops automatically.
struct VideoPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let pv = AVPlayerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        pv.player = player
        pv.controlsStyle = .none
        pv.videoGravity = .resizeAspectFill
        player.play()
        // Loop
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main
        ) { _ in player.seek(to: .zero); player.play() }
        return pv
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player?.currentItem?.asset as? AVURLAsset != nil {
            let existing = (nsView.player?.currentItem?.asset as? AVURLAsset)?.url
            if existing != url {
                let newPlayer = AVPlayer(url: url)
                newPlayer.isMuted = true
                newPlayer.play()
                nsView.player = newPlayer
            }
        }
    }
}

/// Picks a random playable video from the GrimoireVol2 drive.
enum GrimoireLibrary {
    static let extensions = ["mkv","mp4","mov","avi","m4v"]

    static func randomVideoURL() -> URL? {
        let roots = [
            "/Volumes/GrimoireVol2/Movies",
            "/Volumes/GrimoireVol2/Shows",
        ]
        let fm = FileManager.default
        var candidates: [URL] = []
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in items {
                let full = "\(root)/\(item)"
                let ext  = (item as NSString).pathExtension.lowercased()
                if extensions.contains(ext) {
                    candidates.append(URL(fileURLWithPath: full))
                } else if !ext.isEmpty { continue }
                else {
                    // Might be a folder — look one level deeper
                    if let sub = try? fm.contentsOfDirectory(atPath: full) {
                        for f in sub {
                            let fext = (f as NSString).pathExtension.lowercased()
                            if extensions.contains(fext) {
                                candidates.append(URL(fileURLWithPath: "\(full)/\(f)"))
                            }
                        }
                    }
                }
            }
        }
        return candidates.randomElement()
    }
}
