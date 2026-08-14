import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Clear persisted window frames so the window always opens fresh
        let ud = UserDefaults.standard
        ud.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("NSWindow Frame") }
            .forEach { ud.removeObject(forKey: $0) }
        ud.synchronize()
        // bustts-server is managed by launchd (com.bus.bustts LaunchAgent).
        // Poll until it responds, then notify SpeechManager to switch from AVSpeech.
        pollServerHealth()
    }

    private func pollServerHealth(attempts: Int = 0) {
        guard attempts < 40 else { return }   // give up after 40s
        let url = URL(string: "http://127.0.0.1:7331/health")!
        URLSession.shared.dataTask(with: url) { [weak self] _, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                if ok {
                    SpeechManager.shared.serverDidBecomeReady()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.pollServerHealth(attempts: attempts + 1)
                    }
                }
            }
        }.resume()
    }
}

@main
struct BusBroadcasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var gameStateBridge = GameStateBridge()
    @StateObject private var turnQueue       = TurnQueue()
    @StateObject private var twitchBridge    = TwitchChatBridge()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameStateBridge)
                .environmentObject(turnQueue)
                .environmentObject(turnQueue.moodRegistry)
                .environmentObject(twitchBridge)
                .onAppear {
                    turnQueue.connect(bridge: gameStateBridge)
                    // Auto-connect Twitch chat
                    twitchBridge.connect()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1920, height: 1080)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Broadcast") {
                Button("Start Broadcasting") { turnQueue.start() }
                    .keyboardShortcut("b", modifiers: [.command])
                Button("Stop Broadcasting") { turnQueue.stop() }
                    .keyboardShortcut(".", modifiers: [.command])
                Divider()
                Button("Trigger Kobold Knock") { turnQueue.triggerKoboldKnock() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Divider()
                Button(twitchBridge.isConnected ? "Disconnect Twitch" : "Connect Twitch") {
                    if twitchBridge.isConnected { twitchBridge.disconnect() }
                    else { twitchBridge.connect() }
                }
            }
        }

        // Twitch configuration — accessible via ⌘,
        Settings {
            TwitchConfigView()
                .environmentObject(twitchBridge)
        }
    }
}
