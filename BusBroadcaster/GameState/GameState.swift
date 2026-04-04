import Foundation

/// Mirrors the JSON state object served by the JS game at localhost:8765/state
struct GameState: Codable, Equatable {
    /// Police attention / triangulation level: 0.0 – 100.0
    var heat: Double
    /// Broadcast signal strength: 0.0 – 100.0
    var signal: Double
    /// Diesel/fuel remaining: 0.0 – 100.0
    var fuel: Double
    /// Equipment part integrity: 0.0 – 100.0
    var parts: Double
    /// Currently playing track, if any
    var currentSong: String?

    static var `default`: GameState {
        GameState(heat: 0, signal: 60, fuel: 85, parts: 100, currentSong: nil)
    }

    // MARK: - Derived state helpers

    var heatLevel: HeatLevel {
        switch heat {
        case ..<30:  return .low
        case ..<60:  return .medium
        case ..<80:  return .high
        default:     return .critical
        }
    }

    var isDetectiveThreat: Bool { heat > 80 }
}

enum HeatLevel {
    case low, medium, high, critical

    var label: String {
        switch self {
        case .low:      return "COLD"
        case .medium:   return "WARM"
        case .high:     return "HOT"
        case .critical: return "CRITICAL"
        }
    }
}
