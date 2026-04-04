import SwiftUI

// MARK: - MoodIndicatorView
//
// Compact soul-forge EmoBar renderer for a character sleeve.
//
// compact: true  → SceneView sprites  — dot + emotion word + ⚠ if divergent
// compact: false → ChatPanelView rows — dot + emotion + SI value + ⚠

struct MoodIndicatorView: View {
    let mood:    MoodState
    var compact: Bool = false

    /// Dot diameter: 4–10 pt, scaled by arousal (0–10)
    private var dotDiameter: CGFloat {
        4.0 + CGFloat(mood.arousal / 10.0) * 6.0
    }

    var body: some View {
        if compact { compactView } else { fullView }
    }

    // MARK: - Compact (below sprite in SceneView)

    private var compactView: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(mood.stressColor)
                .frame(width: dotDiameter, height: dotDiameter)
                .shadow(color: mood.stressColor.opacity(0.8), radius: 3)
            Text(mood.emotion)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(mood.stressColor.opacity(0.9))
                .lineLimit(1)
            if mood.isDivergent {
                Text("⚠").font(.system(size: 6)).foregroundColor(Color(hex: "#ffaa00"))
            }
        }
    }

    // MARK: - Full (next to name in ChatPanelView)

    private var fullView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(mood.stressColor)
                .frame(width: dotDiameter, height: dotDiameter)
                .shadow(color: mood.stressColor.opacity(0.6), radius: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(mood.emotion)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(mood.stressColor)
                Text(String(format: "SI %.1f", mood.stressIndex))
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(mood.stressColor.opacity(0.65))
            }
            if mood.isDivergent {
                Text("⚠")
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: "#ffaa00"))
                    .help("Behavioral divergence — text signals contradict self-report")
            }
        }
    }
}
