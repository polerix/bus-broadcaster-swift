import SwiftUI

/// Renders shadowy Kobold sprites at van-edge positions with sine-wave opacity.
struct KoboldOverlay: View {
    @EnvironmentObject var turnQueue: TurnQueue

    // Fixed spawn positions — near windows/doors of the van
    private let spawnPoints: [(position: CGPoint, index: Int)] = [
        (CGPoint(x: 97,  y: 118), 0),   // left window
        (CGPoint(x: 603, y: 138), 1),   // right window
        (CGPoint(x: 195, y: 252), 2),   // rear-left door
        (CGPoint(x: 455, y: 252), 3),   // rear-right door
    ]

    @State private var phase:     Double = 0
    @State private var isVisible: Bool   = false
    @State private var action:    KoboldAction = .idle

    var opacity: Double {
        let t = (sin(phase) + 1) / 2
        return KoboldSession.opacityMin + t * (KoboldSession.opacityMax - KoboldSession.opacityMin)
    }

    var body: some View {
        ZStack {
            ForEach(spawnPoints, id: \.index) { point in
                KoboldSprite(spriteName: action.spriteName)
                    .position(point.position)
                    .opacity(isVisible ? opacity : 0)
                    .animation(.easeInOut(duration: 0.6), value: isVisible)
            }
        }
        .onAppear { startPulse() }
        // Show kobolds whenever the turnQueue has a blocking kobold message
        .onChange(of: turnQueue.messages.count) { _, _ in
            let hasKobold = turnQueue.messages.last?.character == "Kobold"
            withAnimation { isVisible = hasKobold }
        }
    }

    private func startPulse() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            phase += (1.0 / 60.0) / KoboldSession.pulsePeriod * 2 * .pi
        }
    }
}

// MARK: - Individual Kobold Sprite

struct KoboldSprite: View {
    let spriteName: String
    let size = CGSize(width: 24, height: 48)

    var body: some View {
        ZStack {
            if let img = NSImage(named: spriteName) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: size.width, height: size.height)
            } else {
                placeholderKobold
            }
        }
        .compositingGroup()
        .shadow(color: Color(hex: "#9B7FD4").opacity(0.7), radius: 10)
    }

    private var placeholderKobold: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#9B7FD4").opacity(0.7), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 18
                    )
                )
                .frame(width: size.width, height: size.height)

            VStack(spacing: 1) {
                Text("👾")
                    .font(.system(size: 10))
                Text("\(spriteName).svg")
                    .font(.system(size: 4, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
