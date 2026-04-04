import SwiftUI
import AppKit

struct CharacterSprite: View {
    let name:       String
    let role:       String
    let spriteName: String
    var isSpeaking: Bool     = false
    var mood:       MoodState = MoodState()

    @State private var bobOffset: CGFloat = 0

    // Reference sprite sizes (authored at 700-wide canvas)
    var spriteSize: CGSize {
        if name == "Felix"                      { return CGSize(width: 32, height: 64) }
        if name == "Prophet" || name == "Nadia" { return CGSize(width: 40, height: 80) }
        return CGSize(width: 48, height: 96)
    }

    var nameColor: Color { CharacterPalette.color(for: name) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                spriteBody
                if isSpeaking { speakingIndicator }
            }
            .offset(y: bobOffset)
            .onAppear { startBob() }
            .clipped()

            // soul-forge EmoBar — compact mood indicator below sprite
            MoodIndicatorView(mood: mood, compact: true)

            Text(name)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(nameColor)
                .lineLimit(1)
                .fixedSize()

            Text(role)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .lineLimit(1)
                .fixedSize()
        }
        // Prevent the VStack from expanding beyond what the canvas needs
        .fixedSize()
    }

    // MARK: - Sprite body

    @ViewBuilder
    private var spriteBody: some View {
        if let img = NSImage(named: spriteName) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.none)
                .frame(width: spriteSize.width, height: spriteSize.height)
                .clipped()
        } else {
            placeholderRect
        }
    }

    private var placeholderRect: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(nameColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(nameColor.opacity(0.7), lineWidth: 1)
                )
            VStack(spacing: 1) {
                Text(String(name.prefix(3)).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(nameColor)
                Text("\(spriteName).svg")
                    .font(.system(size: 5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 2)
            }
        }
        .frame(width: spriteSize.width, height: spriteSize.height)
        .clipped()
    }

    // MARK: - Speaking indicator (3-bar EQ pulse)

    private var speakingIndicator: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 3, height: 4 + CGFloat(i == 1 ? 4 : 0))
                        .animation(
                            .easeInOut(duration: 0.25 + Double(i) * 0.07)
                                .repeatForever(autoreverses: true),
                            value: isSpeaking
                        )
                }
            }
            .padding(.horizontal, 3).padding(.vertical, 2)
            .background(Color.black.opacity(0.65))
            .cornerRadius(3)
            Spacer()
        }
        .frame(width: spriteSize.width, height: spriteSize.height, alignment: .top)
        .clipped()
    }

    // MARK: - Bob animation

    private func startBob() {
        let dur = Double.random(in: 1.8...2.6)
        withAnimation(.easeInOut(duration: dur).repeatForever(autoreverses: true)) {
            bobOffset = -2.5
        }
    }
}
