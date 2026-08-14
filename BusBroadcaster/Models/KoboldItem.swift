import Foundation

struct KoboldItem: Identifiable {
    let id:         UUID
    let name:       String
    let acquiredAt: Date

    init(name: String) {
        id         = UUID()
        self.name  = name
        acquiredAt = Date()
    }

    /// How long ago the item appeared, shown in the cache panel.
    var ageLabel: String {
        let seconds = Date().timeIntervalSince(acquiredAt)
        if seconds < 60      { return "just now" }
        if seconds < 3600    { return "\(Int(seconds/60))m ago" }
        return "\(Int(seconds/3600))h ago"
    }
}
