import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove any persisted NSWindow frame so defaultSize / WindowMaximizer wins
        let ud = UserDefaults.standard
        ud.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("NSWindow Frame") }
            .forEach { ud.removeObject(forKey: $0) }
        ud.synchronize()
    }
}

@main
struct BusBroadcasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var gameStateBridge = GameStateBridge()
    @StateObject private var turnQueue = TurnQueue()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameStateBridge)
                .environmentObject(turnQueue)
                .environmentObject(turnQueue.moodRegistry)
                .onAppear {
                    turnQueue.connect(bridge: gameStateBridge)
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
            }
        }
    }
}
