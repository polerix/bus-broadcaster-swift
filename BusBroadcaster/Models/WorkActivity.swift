import Foundation
import SwiftUI

enum WorkActivityType: Equatable {
    case research(source: String)
    case videoPreview(path: String)
    case scheduling
    case signalMonitor
    case routing
    case maintenance(task: String)
    case surveillance
    case scouting
    case transmitting
    
    // Camera-specific stations
    case camera(station: String)
    case statusScreen
}

struct WorkActivity: Identifiable {
    let id: UUID
    let character: String
    let type: WorkActivityType
    var displayText: String
    var isActive: Bool
    let startTime: Date

    init(id: UUID = UUID(), character: String = "System", type: WorkActivityType, displayText: String = "", isActive: Bool = true) {
        self.id = id; self.character = character; self.type = type
        self.displayText = displayText; self.isActive = isActive; self.startTime = Date()
    }

    var typeLabel: String {
        switch type {
        case .research(let src):     return "RESEARCH · \(src)"
        case .videoPreview:          return "PREVIEW"
        case .scheduling:            return "SCHEDULING"
        case .signalMonitor:         return "SIGNAL WATCH"
        case .routing:               return "ROUTING"
        case .maintenance(let task): return task.uppercased()
        case .surveillance:          return "SURVEILLANCE"
        case .scouting:              return "SCOUTING"
        case .transmitting:          return "TRANSMITTING"
        case .camera(let station):   return "CAM · \(station.uppercased())"
        case .statusScreen:          return "DIAGNOSTICS"
        }
    }

    var nameColor: Color { 
        if character == "System" { return .white.opacity(0.4) }
        return CharacterPalette.color(for: character) 
    }

    static func makeType(for name: String) -> WorkActivityType {
        switch name {
        case "Felix":            return .research(source: "Reddit · YT")
        case "Soren":            return .videoPreview(path: "")
        case "Dolores":          return .scheduling
        case "Priya":            return .signalMonitor
        case "Marcus":           return .routing
        case "Yael":             return .maintenance(task: "Systems check")
        case "Detective Morrow": return .surveillance
        case "Prophet", "Nadia": return .scouting
        default:                 return .transmitting
        }
    }
}
