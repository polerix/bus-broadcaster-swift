import Foundation

/// Polls Reddit hot posts + YouTube RSS and distils them into a
/// short plain-text summary injected into every apfel prompt.
/// No API keys needed — public JSON/RSS only.
final class ContentFetcher {

    private var timer: Timer?
    private let subreddits = ["news", "music", "worldnews", "listentothis"]
    private let youtubeFeeds = [
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC16niRr50-MSBwiO3YDb3RA",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC4eYXhJI4-7wSWc8UNRwD4A",
    ]

    private var redditItems:  [String] = []
    private var youtubeItems: [String] = []

    init() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 720, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }
    deinit { timer?.invalidate() }

    func currentSummary() -> String {
        var parts: [String] = []
        if !redditItems.isEmpty {
            parts.append("=== LIVE FEED (Reddit) ===\n"
                + Array(redditItems.shuffled().prefix(5)).joined(separator: "\n"))
        }
        if !youtubeItems.isEmpty {
            parts.append("=== YOUTUBE ===\n"
                + Array(youtubeItems.shuffled().prefix(3)).joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }

    private func fetch() {
        for sub in subreddits { fetchReddit(sub: sub) }
        for feed in youtubeFeeds { fetchYouTube(url: feed) }
    }

    private func fetchReddit(sub: String) {
        guard let url = URL(string: "https://www.reddit.com/r/\(sub)/hot.json?limit=6") else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("BusBroadcaster/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let outer = json["data"] as? [String: Any],
                  let children = outer["children"] as? [[String: Any]] else { return }
            let titles: [String] = children.compactMap { child in
                guard let d = child["data"] as? [String: Any],
                      let title = d["title"] as? String,
                      let score = d["score"] as? Int, score > 50 else { return nil }
                return "r/\(sub): \(title)"
            }
            DispatchQueue.main.async {
                self.redditItems = Array(Set(self.redditItems + titles)).prefix(20).map { $0 }
            }
        }.resume()
    }

    private func fetchYouTube(url urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let xml = String(data: data, encoding: .utf8) else { return }
            let titles = xml.components(separatedBy: "<title>")
                .dropFirst(2).prefix(4)
                .compactMap { chunk -> String? in
                    guard let end = chunk.range(of: "</title>") else { return nil }
                    let t = String(chunk[chunk.startIndex..<end.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : "YT: \(t)"
                }
            DispatchQueue.main.async {
                self.youtubeItems = Array(Set(self.youtubeItems + Array(titles))).prefix(10).map { $0 }
            }
        }.resume()
    }
}
