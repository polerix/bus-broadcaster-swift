import SwiftUI
import AppKit

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
        VStack(spacing: 0) {
            // Row 1: Top Menu Bar
            TopMenuBarView()
                .frame(height: 32)

            // Row 2: Three columns (Chat, Activity, Transmission)
            HSplitView {
                // Column 1: Chat Interface
                ChatPanelView()
                    .frame(minWidth: 260, idealWidth: 380, maxWidth: .infinity)

                // Column 2: Activity
                WorkPanelView()
                    .frame(minWidth: 300, idealWidth: 580, maxWidth: .infinity)

                // Column 3: Transmission Screens
                VSplitView {
                    SceneView()
                        .frame(minHeight: 200, idealHeight: 400)
                    BroadcastWindowView()
                        .frame(minHeight: 160, idealHeight: 300)
                }
                .frame(minWidth: 300, idealWidth: 600, maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Row 3: Internal Communication
            InternalCommView()
                .frame(height: 120)
                .background(Color.black.opacity(0.4))
                .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.1)), alignment: .top)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .background(WindowMaximizer())
    }
}
