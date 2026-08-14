import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let character: String
    var text: String
    let timestamp: Date
    var isStreaming: Bool

    init(character: String, text: String, timestamp: Date = Date(),
         isStreaming: Bool = false) {
        self.id        = UUID()
        self.character = character
        self.text      = text
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    var nameColor: Color { CharacterPalette.color(for: character) }
}

// MARK: - Character Palette
enum CharacterPalette {
    static func color(for name: String) -> Color {
        switch name {
        case "Dolores":          return Color(hex: "#FF9F45")
        case "Soren":            return Color(hex: "#A8E6CF")
        case "Priya":            return Color(hex: "#FFD3B6")
        case "Marcus":           return Color(hex: "#DCEDC1")
        case "Yael":             return Color(hex: "#FF8B94")
        case "Felix":            return Color(hex: "#B5EAD7")
        case "Detective Morrow": return Color(hex: "#C7CEEA")
        case "Prophet":          return Color(hex: "#E2D2FF")
        case "Nadia":            return Color(hex: "#FFDAC1")
        case "Kobold":           return Color(hex: "#9B7FD4")
        default:                 return Color(hex: "#8B8B8B")
        }
    }
    static func hexString(for name: String) -> String {
        switch name {
        case "Dolores":          return "#FF9F45"
        case "Soren":            return "#A8E6CF"
        case "Priya":            return "#FFD3B6"
        case "Marcus":           return "#DCEDC1"
        case "Yael":             return "#FF8B94"
        case "Felix":            return "#B5EAD7"
        case "Detective Morrow": return "#C7CEEA"
        case "Prophet":          return "#E2D2FF"
        case "Nadia":            return "#FFDAC1"
        case "Kobold":           return "#9B7FD4"
        default:                 return "#8B8B8B"
        }
    }
}

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double((int      ) & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
