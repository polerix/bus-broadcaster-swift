import Foundation
import CoreGraphics

/// Defines an AI character "sleeve" that can speak in the chat panel.
protocol AgentCharacter: AnyObject {
    /// Display name shown in chat
    var name: String { get }
    /// Short role/callsign label
    var role: String { get }
    /// Full system prompt injected before each apfel call
    var systemPrompt: String { get }
    /// Sprite asset name (without extension) for idle state
    var spriteIdle: String { get }
    /// Position in the scene canvas (pixels)
    var position: CGPoint { get }
    /// Whether this character is physically inside the van
    var isInsideVan: Bool { get }
    /// soul-forge EmoBar mood state — updated by MoodRegistry + BehavioralAnalyzer
    var mood: MoodState { get set }
}
