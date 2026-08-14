import Foundation

// MARK: - TwitchBadge
enum TwitchBadge: String, Equatable, Codable {
    case subscriber
    case vip
    case mod
    case broadcaster
}

// MARK: - ViewerMessage
struct ViewerMessage: Identifiable {
    let id:        UUID
    let username:  String
    let text:      String
    let badges:    [TwitchBadge]
    let timestamp: Date

    init(
        username:  String,
        text:      String,
        badges:    [TwitchBadge] = [],
        timestamp: Date          = Date()
    ) {
        self.id        = UUID()
        self.username  = username
        self.text      = text
        self.badges    = badges
        self.timestamp = timestamp
    }

    var isPrivileged: Bool {
        badges.contains(.subscriber)
            || badges.contains(.vip)
            || badges.contains(.mod)
            || badges.contains(.broadcaster)
    }
}
