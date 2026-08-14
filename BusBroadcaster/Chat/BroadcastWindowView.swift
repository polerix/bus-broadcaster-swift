import SwiftUI
import Combine

struct BroadcastWindowView: View {
    @EnvironmentObject var turnQueue: TurnQueue
    @ObservedObject private var busPlayer = BusPlayer.shared
    @State private var onAirBlink = true
    @State private var tickerOffset: CGFloat = 0
    @State private var scanline: CGFloat = 0
    private let blinker = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()
    private let scanTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            broadcastHeader
            stationIDArea
            lowerThird
            tickerBar
        }
        .background(Color.black)
    }

    // ─── Top bar ────────────────────────────────────────────────────────────────

    private var broadcastHeader: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .opacity(onAirBlink && turnQueue.isRunning ? 1 : 0.15)
                Text(turnQueue.isRunning ? "LIVE BROADCAST" : "STANDBY")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundColor(turnQueue.isRunning ? .red : .white.opacity(0.3))
            }
            Spacer()
            Text("108.7 UHF")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(hex: "#A8E6CF").opacity(0.6))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.8))
        .onReceive(blinker) { _ in onAirBlink.toggle() }
    }

    // ─── Station ID ──────────────────────────────────────────────────────────────

    private var stationIDArea: some View {
        GeometryReader { geo in
            ZStack {
                // Deep space background
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.06, green: 0.04, blue: 0.12),
                        Color.black,
                    ]),
                    center: .center, startRadius: 20, endRadius: max(geo.size.width, geo.size.height)
                )

                // Scanline sweep
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, Color.white.opacity(0.04), .clear]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 40)
                    .offset(y: scanline - geo.size.height / 2)
                    .clipped()

                // Grid lines
                gridLines(size: geo.size)

                // SVG-style station ID
                VStack(spacing: 6) {
                    // Top: freq + callsign cluster
                    HStack(spacing: 16) {
                        freqBadge("108.7")
                        Spacer()
                        freqBadge("UHF PIRATE")
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Main logo
                    VStack(spacing: 2) {
                        Text("BUS")
                            .font(.system(size: min(geo.size.width * 0.18, 72), weight: .black, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B35"), Color(hex: "#FF9F45")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "#FF6B35").opacity(0.6), radius: 12)

                        Text("BROADCASTER")
                            .font(.system(size: min(geo.size.width * 0.055, 22), weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#A8E6CF"))
                            .tracking(6)
                            .shadow(color: Color(hex: "#A8E6CF").opacity(0.4), radius: 6)
                    }

                    Text("TRANSMISSION IS RESISTANCE")
                        .font(.system(size: min(geo.size.width * 0.025, 10), design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(3)

                    // Now-playing strip
                    if !busPlayer.currentTitle.isEmpty {
                        HStack(spacing: 6) {
                            Text("▶")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(Color(hex: "#FFD3B6").opacity(0.7))
                            Text(busPlayer.currentTitle.uppercased())
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(hex: "#FFD3B6").opacity(0.55))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(3)
                    }

                    Spacer()

                    // Signal bars row
                    signalBarsRow
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
            .clipped()
            .onReceive(scanTimer) { _ in
                scanline += 1.2
                if scanline > geo.size.height { scanline = 0 }
            }
        }
    }

    private func gridLines(size: CGSize) -> some View {
        Canvas { ctx, sz in
            let step: CGFloat = 28
            var x: CGFloat = 0
            while x <= sz.width {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: sz.height))
                ctx.stroke(p, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
                x += step
            }
            var y: CGFloat = 0
            while y <= sz.height {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
                y += step
            }
        }
    }

    private func freqBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: "#33FF66").opacity(0.7))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color(hex: "#33FF66").opacity(0.08))
            .cornerRadius(2)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(hex: "#33FF66").opacity(0.3), lineWidth: 1))
    }

    private var signalBarsRow: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { i in
                let active = onAirBlink ? (i < 6) : (i < 5)
                RoundedRectangle(cornerRadius: 1)
                    .fill(active ? Color(hex: "#33FF66").opacity(0.7) : Color.white.opacity(0.1))
                    .frame(width: 6, height: CGFloat(6 + i * 3))
            }
            Spacer()
            Text(turnQueue.isRunning ? "◉ TRANSMITTING" : "○ STANDBY")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(turnQueue.isRunning ? Color(hex: "#33FF66").opacity(0.8) : .white.opacity(0.3))
        }
    }

    // ─── Lower Third ─────────────────────────────────────────────────────────────

    private var lowerThird: some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle().fill(Color(hex: "#FF6B35").opacity(0.5)).frame(height: 1)
            HStack(alignment: .top, spacing: 8) {
                if let speaker = turnQueue.currentSpeaker {
                    Text(speaker.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(CharacterPalette.color(for: speaker))
                        .frame(width: 100, alignment: .leading)
                    if let last = turnQueue.messages.last(where: { $0.character == speaker }) {
                        Text(last.text + (last.isStreaming ? "▌" : ""))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("─")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.04, blue: 0.02), Color.black],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        }
    }

    // ─── Ticker ───────────────────────────────────────────────────────────────────

    private var tickerBar: some View {
        let recentText = turnQueue.messages.suffix(10)
            .filter { !$0.text.isEmpty }
            .map { "[\($0.character.uppercased())] \($0.text)" }
            .joined(separator: "   ·   ")

        return ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.04)
            GeometryReader { geo in
                Text(recentText.isEmpty ? "BUS BROADCASTER · SIGNAL ACTIVE · STAY TUNED" : recentText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF9F45").opacity(0.85))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: tickerOffset)
                    .onAppear {
                        tickerOffset = geo.size.width
                        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                            tickerOffset = -2000
                        }
                    }
                    .onChange(of: turnQueue.messages.count) { _ in
                        tickerOffset = geo.size.width
                        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                            tickerOffset = -2000
                        }
                    }
            }
        }
        .frame(height: 22)
        .clipped()
    }
}
