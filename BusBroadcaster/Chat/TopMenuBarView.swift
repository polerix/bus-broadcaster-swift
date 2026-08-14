import SwiftUI

struct TopMenuBarView: View {
    @EnvironmentObject var turnQueue:    TurnQueue
    @EnvironmentObject var twitchBridge: TwitchChatBridge
    @State private var showWorkStationMenu = false
    @State private var showTwitchConfig = false
    @State private var showInventory = false
    @State private var showSchedule = false
    @State private var showKoboldMenu = false

    private let koboldPurple = Color(hex: "#9B7FD4")

    var body: some View {
        HStack(spacing: 0) {
            // 0. Hamburger Menu (Work Station Detail)
            MenuButton(label: "", icon: "line.3.horizontal") {
                showWorkStationMenu.toggle()
            }
            .popover(isPresented: $showWorkStationMenu, arrowEdge: .bottom) {
                WorkStationDetailPopover()
                    .environmentObject(turnQueue)
            }

            Divider().frame(height: 16).background(Color.white.opacity(0.1)).padding(.horizontal, 4)

            // 1. Settings
            MenuButton(label: "SETTINGS", icon: "gearshape.fill") {
                showTwitchConfig = true
            }
            .sheet(isPresented: $showTwitchConfig) {
                TwitchConfigView()
                    .environmentObject(twitchBridge)
            }

            Divider().frame(height: 16).background(Color.white.opacity(0.1)).padding(.horizontal, 8)

            // 2. Inventory
            MenuButton(label: "INVENTORY", icon: "archivebox.fill") {
                showInventory.toggle()
            }
            .popover(isPresented: $showInventory, arrowEdge: .bottom) {
                InventoryPopoverView()
                    .environmentObject(turnQueue)
            }

            Divider().frame(height: 16).background(Color.white.opacity(0.1)).padding(.horizontal, 8)

            // 3. Schedule
            MenuButton(label: "SCHEDULE", icon: "calendar") {
                showSchedule.toggle()
            }
            .popover(isPresented: $showSchedule, arrowEdge: .bottom) {
                SchedulePopoverView()
            }

            Divider().frame(height: 16).background(Color.white.opacity(0.1)).padding(.horizontal, 8)

            // 4. Kobold Menu
            MenuButton(label: "KOBOLD", icon: "person.fill.viewfinder", color: koboldPurple) {
                showKoboldMenu.toggle()
            }
            .popover(isPresented: $showKoboldMenu, arrowEdge: .bottom) {
                KoboldQuickMenuView()
                    .environmentObject(turnQueue)
            }

            Spacer()

            // Status indicators
            HStack(spacing: 12) {
                if turnQueue.isRunning {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
                
                if let speaker = turnQueue.currentSpeaker {
                    Text("ON AIR: \(speaker.uppercased())")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                Button(action: { turnQueue.restart() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                        Text("RESTART")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 12)
        }
        .frame(height: 32)
        .background(Color.black.opacity(0.8))
        .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.1)), alignment: .bottom)
    }
}

// MARK: - Sub-components

struct MenuButton: View {
    let label: String
    let icon: String
    var color: Color = .white.opacity(0.7)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct InventoryPopoverView: View {
    @EnvironmentObject var turnQueue: TurnQueue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KOBOLD CACHE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#9B7FD4"))
                .padding(.bottom, 4)
            
            if turnQueue.koboldInventory.isEmpty {
                Text("empty")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                ForEach(turnQueue.koboldInventory) { item in
                    HStack {
                        Text("• \(item.name)")
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Button {
                            turnQueue.removeFromKoboldCache(id: item.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
    }
}

struct SchedulePopoverView: View {
    let schedule = [
        ("00:00–05:00", "DEAD AIR / OVERNIGHT DRIFT"),
        ("05:00–07:00", "SIGNAL WARMUP"),
        ("07:00–09:00", "MORNING INTEL"),
        ("09:00–11:00", "OPEN CHANNEL"),
        ("11:00–13:00", "MIDDAY MISSION"),
        ("13:00–15:00", "HEAT WATCH"),
        ("15:00–17:00", "CONTENT BLOCK"),
        ("17:00–19:00", "RUSH HOUR TRANSMISSION"),
        ("19:00–21:00", "NIGHT FREQUENCY"),
        ("21:00–00:00", "KOBOLD WINDOW")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BROADCAST RUNSHEET")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
                .padding(.bottom, 4)
            
            ForEach(schedule, id: \.0) { time, task in
                HStack(alignment: .top) {
                    Text(time)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 80, alignment: .leading)
                    Text(task)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
    }
}

struct KoboldQuickMenuView: View {
    @EnvironmentObject var turnQueue: TurnQueue
    
    var body: some View {
        VStack(spacing: 2) {
            QuickActionButton(label: "TRIGGER KNOCK") { turnQueue.triggerKoboldKnock() }
            QuickActionButton(label: "TRIGGER NOTE") { turnQueue.triggerKoboldNote() }
        }
        .padding(4)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
    }
}

struct QuickActionButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
        }
        .buttonStyle(.plain)
    }
}

struct WorkStationDetailPopover: View {
    @EnvironmentObject var turnQueue: TurnQueue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MISSION CONTROL OVERVIEW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.8))
                .padding(12)
            
            Divider().background(Color.white.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let allFeeds = turnQueue.cameraStations + turnQueue.workActivities.filter(\.isActive)
                    
                    ForEach(allFeeds) { feed in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(turnQueue.currentSpeaker == feed.character ? .red : feed.nameColor)
                                .frame(width: 6, height: 6)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(feed.character.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(feed.nameColor)
                                Text(feed.typeLabel)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Spacer()
                            
                            if turnQueue.currentSpeaker == feed.character && turnQueue.isRunning {
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(turnQueue.currentSpeaker == feed.character ? 0.08 : 0.02))
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 300)
        }
        .frame(width: 260)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
    }
}
