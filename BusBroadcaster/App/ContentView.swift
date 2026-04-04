import SwiftUI
import AppKit

// Grabs the NSWindow directly from the view hierarchy — fires once on first appear.
// This is the only reliable way to resize the window from inside a swiftc-compiled
// SwiftUI app where NSApp.windows may be empty at launch time.
private struct WindowMaximizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let win = view.window else { return }
            let screen = win.screen ?? NSScreen.main
            guard let frame = screen?.frame else { return }
            win.setFrame(frame, display: true, animate: false)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var gameStateBridge: GameStateBridge
    @EnvironmentObject var turnQueue: TurnQueue

    var body: some View {
        VSplitView {
            SceneView()
                .frame(minWidth: 700, maxWidth: .infinity,
                       minHeight: 280, idealHeight: 720, maxHeight: .infinity)

            ChatPanelView()
                .frame(minWidth: 700, maxWidth: .infinity,
                       minHeight: 180, idealHeight: 360, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .background(WindowMaximizer())
    }
}
