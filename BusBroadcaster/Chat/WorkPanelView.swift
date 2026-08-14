import SwiftUI

struct WorkPanelView: View {
    @EnvironmentObject var turnQueue: TurnQueue

    var body: some View {
        VStack(spacing: 0) {
            workHeader
            workBody
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.07))
    }

    private var workHeader: some View {
        HStack {
            Text("⚙️ MISSION CONTROL")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(Color(hex: "#FFD3B6"))
            Spacer()
            let n = turnQueue.cameraStations.count + turnQueue.workActivities.filter(\.isActive).count
            Text("\(n) FEEDS ACTIVE")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD3B6").opacity(0.7))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
    }

    private var workBody: some View {
        GeometryReader { geo in
            ScrollView {
                let activeActivities = turnQueue.workActivities.filter(\.isActive)
                let allFeeds = turnQueue.cameraStations + activeActivities
                
                activityGrid(allFeeds, size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func activityGrid(_ activities: [WorkActivity], size: CGSize) -> some View {
        let cols = 3
        let cellH: CGFloat = 160

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: cols),
            spacing: 2
        ) {
            ForEach(activities) { activity in
                ActivityCardView(activity: activity)
                    .frame(height: cellH)
            }
        }
        .padding(2)
    }
}

// MARK: - Activity Card

struct ActivityCardView: View {
    let activity: WorkActivity
    @EnvironmentObject var turnQueue: TurnQueue
    @EnvironmentObject var gameStateBridge: GameStateBridge
    
    @State private var pulse: Bool = false
    @State private var frameCount: Int = 0
    private let ticker = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    var isSpeaking: Bool {
        turnQueue.currentSpeaker == activity.character
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background tint from character color
            if isSpeaking {
                activity.nameColor.opacity(0.15)
            } else {
                activity.nameColor.opacity(0.04)
            }
            Color.black.opacity(0.55)

            VStack(alignment: .leading, spacing: 4) {
                // Header row
                HStack(spacing: 6) {
                    Circle()
                        .fill(isSpeaking ? .red : activity.nameColor)
                        .frame(width: 6, height: 6)
                        .opacity(pulse ? 1.0 : 0.3)
                    
                    Text(activity.character.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(activity.nameColor)
                    
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(activity.typeLabel)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    if isSpeaking && turnQueue.isRunning {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(2)
                    }
                }

                // Content area
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(isSpeaking ? Color.red.opacity(0.4) : activity.nameColor.opacity(0.2), lineWidth: 1)
        )
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { pulse = true } }
        .onReceive(ticker) { _ in frameCount += 1 }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch activity.type {
        case .statusScreen:
            statusScreenView
        case .camera(let station):
            cameraPlaceholderView(station)
        case .research:
            researchView
        case .videoPreview(let path):
            if !path.isEmpty, let url = URL(string: "file://\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)") {
                VideoPlayerView(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(2)
            } else {
                videoPlaceholder
            }
        case .signalMonitor:
            signalMonitorView
        case .scheduling:
            schedulingView
        case .routing:
            routingView
        case .maintenance:
            maintenanceView
        case .surveillance:
            surveillanceView
        case .scouting, .transmitting:
            genericTransmitView
        }
    }

    // Diagnostics: Heat, Signal, Fuel, Parts
    private var statusScreenView: some View {
        let state = gameStateBridge.state
        return VStack(alignment: .leading, spacing: 6) {
            Spacer()
            DiagnosticRow(label: "HEAT",   value: state.heat,   color: .red)
            DiagnosticRow(label: "SIGNAL", value: state.signal, color: .green)
            DiagnosticRow(label: "FUEL",   value: state.fuel,   color: .yellow)
            DiagnosticRow(label: "PARTS",  value: state.parts,  color: .cyan)
            Spacer()
        }
    }

    private func cameraPlaceholderView(_ station: String) -> some View {
        ZStack {
            Color.black.opacity(0.4)
            
            // Visual static / grid pattern
            Canvas { ctx, sz in
                let step: CGFloat = 12
                for x in stride(from: 0, to: sz.width, by: step) {
                    for y in stride(from: 0, to: sz.height, by: step) {
                        if (Int(x/step) + Int(y/step) + frameCount/10) % 7 == 0 {
                            ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.05)))
                        }
                    }
                }
            }
            
            VStack {
                Spacer()
                Text("FEED: \(station.uppercased())")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(4)
                    .background(Color.black.opacity(0.4))
            }
        }
        .cornerRadius(2)
    }

    // Research: scrolling text feed
    private var researchView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(activity.displayText.isEmpty ? "Connecting to feeds..." : activity.displayText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "#B5EAD7").opacity(0.85))
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: false)
            Spacer(minLength: 0)
        }
    }

    // Signal monitor: animated bars
    private var signalMonitorView: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<12, id: \.self) { i in
                var rng = seededRng(i + frameCount); let h = CGFloat(20 + Int.random(in: 0...50, using: &rng))
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(h))
                    .frame(width: 5, height: h)
                    .animation(.easeInOut(duration: 0.1), value: h)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    // Scheduling: typewriter text
    private var schedulingView: some View {
        let lines = [
            "05:00 — SIGNAL WARMUP",
            "07:00 — MORNING INTEL",
            "09:00 — OPEN CHANNEL",
            "11:00 — MIDDAY MISSION",
            "15:00 — CONTENT BLOCK",
            "17:00 — RUSH HOUR TX",
            "21:00 — KOBOLD WINDOW",
        ]
        let shown = min(lines.count, 1 + frameCount / 30)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<shown, id: \.self) { i in
                Text(lines[i])
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF9F45").opacity(0.8))
            }
            if shown < lines.count { Text("▌").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5)) }
            Spacer(minLength: 0)
        }
    }

    // Routing: ASCII route
    private var routingView: some View {
        let routes = ["[A] ──── [B] ──── [C]", "          ↓", "         [X] (alt)"]
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(routes, id: \.self) { line in
                Text(line)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#DCEDC1").opacity(0.7))
            }
            Spacer(minLength: 0)
        }
    }

    // Maintenance: animated status ticks
    private var maintenanceView: some View {
        let tasks = [("ENGINE", true), ("FUEL LINE", true), ("GENERATOR", frameCount > 40), ("EXHAUST", frameCount > 80)]
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(tasks, id: \.0) { task, ok in
                HStack(spacing: 5) {
                    Text(ok ? "✓" : "…")
                        .foregroundColor(ok ? Color(hex: "#DCEDC1") : .yellow)
                    Text(task)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 9, design: .monospaced))
    }

    // Surveillance: scanline pattern
    private var surveillanceView: some View {
        ZStack {
            Color.black.opacity(0.4)
            VStack(spacing: 4) {
                Text("SCANNING AREA")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#C7CEEA").opacity(0.6))
                Rectangle()
                    .fill(Color(hex: "#C7CEEA").opacity(0.08))
                    .frame(height: 1)
                    .offset(y: CGFloat(frameCount % 60) - 30)
            }
        }
        .cornerRadius(3)
    }

    // Generic
    private var genericTransmitView: some View {
        Text(activity.displayText.prefix(120))
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
            .lineLimit(6)
            .fixedSize(horizontal: false, vertical: false)
    }

    private var videoPlaceholder: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: 4) {
                Text("🎬")
                Text("Selecting clip...")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .cornerRadius(3)
    }

    private func barColor(_ h: CGFloat) -> Color {
        h > 55 ? Color(hex: "#FF8B94") : h > 35 ? Color(hex: "#A8E6CF") : Color(hex: "#4CAF50")
    }

    // Pseudo-random deterministic enough for bar heights
    private func seededRng(_ seed: Int) -> AnyRandomNumberGenerator {
        AnyRandomNumberGenerator(seed: UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407)))
    }
}

// MARK: - Diagnostic Row

struct DiagnosticRow: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 45, alignment: .leading)
            
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                Capsule().fill(color.opacity(0.6))
                    .frame(width: 80 * CGFloat(value / 100), height: 6)
            }
            .frame(width: 80)
            
            Text("\(Int(value))%")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &= state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
