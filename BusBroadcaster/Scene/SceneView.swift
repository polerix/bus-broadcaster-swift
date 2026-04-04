import SwiftUI

struct SceneView: View {
    @EnvironmentObject var gameStateBridge: GameStateBridge
    @EnvironmentObject var turnQueue:       TurnQueue
    @EnvironmentObject var moodRegistry:    MoodRegistry

    // Canvas reference size — all positions/sizes are authored at this resolution.
    // Scale is computed at render time so the canvas fills available width.
    private let canvasWidth:  CGFloat = 700
    private let canvasHeight: CGFloat = 320

    private let vanRect = CGRect(x: 100, y: 30, width: 500, height: 220)

    private let insideLayout: [(name: String, role: String, sprite: String, pos: CGPoint)] = [
        ("Dolores", "Dispatch",          "dispatcher-idle", CGPoint(x: 158, y: 128)),
        ("Soren",   "DJ Static",         "dj-idle",         CGPoint(x: 238, y: 108)),
        ("Priya",   "Engineer Ohm",      "engineer-idle",   CGPoint(x: 318, y: 148)),
        ("Marcus",  "Ghost / Driver",    "driver-idle",     CGPoint(x: 398, y: 118)),
        ("Yael",    "Rivet / Mechanic",  "mechanic-idle",   CGPoint(x: 468, y: 158)),
        ("Felix",   "Frequency",         "lookout-idle",    CGPoint(x: 538, y: 98)),
    ]

    private let outsideLayout: [(name: String, role: String, sprite: String, pos: CGPoint)] = [
        ("Prophet", "Vagrant", "prophet-idle", CGPoint(x: 55,  y: 185)),
        ("Nadia",   "Vendor",  "nadia-idle",   CGPoint(x: 645, y: 185)),
    ]

    var body: some View {
        GeometryReader { geo in
            // Scale canvas to fill available width exactly.
            // Height follows proportionally; clip if container is shorter.
            let scale = geo.size.width / canvasWidth

            ZStack(alignment: .topLeading) {
                // ── Background ──────────────────────────────────────────
                Rectangle()
                    .fill(Color(red: 0.07, green: 0.06, blue: 0.05))

                // ── Road / ground ────────────────────────────────────────
                Rectangle()
                    .fill(Color(red: 0.12, green: 0.11, blue: 0.09))
                    .frame(height: canvasHeight * 0.28)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // ── Van body ─────────────────────────────────────────────
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.13, green: 0.12, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.38, green: 0.32, blue: 0.18), lineWidth: 1.5)
                    )
                    .frame(width: vanRect.width, height: vanRect.height)
                    .position(x: vanRect.midX, y: vanRect.midY)

                // ── Van label ────────────────────────────────────────────
                Text("BUS BROADCASTER  —  ON AIR")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.35, green: 0.30, blue: 0.14).opacity(0.7))
                    .position(x: vanRect.midX, y: vanRect.minY + 10)

                // ── Inside characters ────────────────────────────────────
                ForEach(insideLayout, id: \.name) { c in
                    CharacterSprite(
                        name:       c.name,
                        role:       c.role,
                        spriteName: c.sprite,
                        isSpeaking: turnQueue.currentSpeaker == c.name,
                        mood:       moodRegistry.mood(for: c.name)
                    )
                    .position(c.pos)
                }

                // ── Outside characters ───────────────────────────────────
                ForEach(outsideLayout, id: \.name) { c in
                    CharacterSprite(
                        name:       c.name,
                        role:       c.role,
                        spriteName: c.sprite,
                        isSpeaking: turnQueue.currentSpeaker == c.name,
                        mood:       moodRegistry.mood(for: c.name)
                    )
                    .position(c.pos)
                }

                // ── Detective Morrow — conditional on heat > 80 ──────────
                if gameStateBridge.state.isDetectiveThreat {
                    CharacterSprite(
                        name:       "Detective Morrow",
                        role:       "Threat",
                        spriteName: "detective-idle",
                        isSpeaking: turnQueue.currentSpeaker == "Detective Morrow",
                        mood:       moodRegistry.mood(for: "Detective Morrow")
                    )
                    .position(CGPoint(x: 350, y: 268))
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                // ── Kobold overlay ───────────────────────────────────────
                KoboldOverlay()

                // ── CRT scanline texture ─────────────────────────────────
                ScanlineOverlay()
                    .allowsHitTesting(false)
                    .opacity(0.06)

                // ── HUD bar ───────────────────────────────────────────────
                VStack {
                    HUDBar(state: gameStateBridge.state,
                           isConnected: gameStateBridge.isConnected,
                           turnQueue: turnQueue)
                    Spacer()
                }
            }
            // Size the canvas at reference dimensions, then scale to fill width
            .frame(width: canvasWidth, height: canvasHeight)
            .scaleEffect(scale, anchor: .topLeading)
            // After scaling, occupy the correct pixel footprint
            .frame(width: geo.size.width,
                   height: canvasHeight * scale,
                   alignment: .topLeading)
        }
        // Clip any vertical overflow when the panel is shorter than the scaled canvas
        .clipped()
        .animation(.easeInOut(duration: 0.4), value: gameStateBridge.state.isDetectiveThreat)
    }
}

// MARK: - HUD Bar

struct HUDBar: View {
    let state:       GameState
    let isConnected: Bool
    let turnQueue:   TurnQueue

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isConnected ? Color.green : Color(hex: "#FF9F45"))
                .frame(width: 6, height: 6)
                .help(isConnected ? "Connected to localhost:8765" : "Simulating (game not running)")

            StatBar(label: "HEAT",  value: state.heat,   color: heatColor)
            StatBar(label: "SIG",   value: state.signal, color: .green)
            StatBar(label: "FUEL",  value: state.fuel,   color: .yellow)
            StatBar(label: "PARTS", value: state.parts,  color: .cyan)

            if let song = state.currentSong {
                Text("♫ \(song)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            Text(state.heatLevel.label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundColor(heatColor)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(heatColor.opacity(0.15))
                .cornerRadius(3)

            Button(turnQueue.isRunning ? "■ STOP" : "▶ BROADCAST") {
                turnQueue.isRunning ? turnQueue.stop() : turnQueue.start()
            }
            .font(.system(.caption, design: .monospaced).bold())
            .buttonStyle(.borderedProminent)
            .tint(turnQueue.isRunning ? .red.opacity(0.7) : .green.opacity(0.7))

            Button("👾 KNOCK") { turnQueue.triggerKoboldKnock() }
                .font(.system(.caption, design: .monospaced))
                .buttonStyle(.bordered)
                .tint(Color(hex: "#9B7FD4").opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.black.opacity(0.72))
    }

    private var heatColor: Color {
        switch state.heatLevel {
        case .low:      return .green
        case .medium:   return .yellow
        case .high:     return Color(hex: "#FF9F45")
        case .critical: return .red
        }
    }
}

// MARK: - Stat Bar

struct StatBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 30, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(width: 52, height: 7)
                Capsule().fill(color.opacity(0.75))
                    .frame(width: 52 * CGFloat(value / 100), height: 7)
            }
            Text("\(Int(value))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 22, alignment: .trailing)
        }
    }
}

// MARK: - CRT Scanline Overlay

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                             with: .color(.black))
                    y += 3
                }
            }
        }
    }
}
