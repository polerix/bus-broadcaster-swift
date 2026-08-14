import Foundation
import Combine

// MARK: - KoboldDriver protocol
/// Both AI and human-controlled kobolds implement this.
protocol KoboldDriver: AnyObject {
    var name: String { get }
    func respond(
        context: String,
        gameState: GameState,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    )
}

// MARK: - KoboldDriverType enum
enum KoboldDriverType {
    case ai(KoboldAI)
    case human(WebSocketKoboldConnection)

    var driver: any KoboldDriver {
        switch self {
        case .ai(let k):    return k
        case .human(let w): return w
        }
    }

    var name: String { driver.name }
}

// MARK: - KoboldAction
enum KoboldAction: Equatable {
    case idle, knock, slipNote, steal, trade

    var spriteName: String {
        switch self {
        case .idle:     return "kobold-idle-shadow"
        case .knock:    return "kobold-knock"
        case .slipNote: return "kobold-slip-note"
        case .steal:    return "kobold-steal"
        case .trade:    return "kobold-trade"
        }
    }

    var chatLabel: String {
        switch self {
        case .idle:     return "*a shadow drifts at the window*"
        case .knock:    return "*knock knock knock*"
        case .slipNote: return "*a folded note slides under the door*"
        case .steal:    return "*something small goes missing*"
        case .trade:    return "*an exchange happens at the threshold*"
        }
    }
}

// MARK: - KoboldSession
/// Manages a single Kobold instance: opacity pulse, action state, driver dispatch.
class KoboldSession: ObservableObject {

    // MARK: Shared singleton reference (set on every init, weak to avoid cycle)
    static weak var shared: KoboldSession?

    @Published var isVisible:      Bool         = false
    @Published var opacity:        Double       = 0.18
    @Published var currentAction:  KoboldAction = .idle

    let driverType: KoboldDriverType

    /// Set by TurnQueue so that slipNote(_:) can inject text into the chat log.
    var noteInjectionHandler: ((String) -> Void)?

    private var opacityTimer: Timer?
    private var phase:        Double = 0

    // Sine-wave opacity: period 2400 ms, range 0.18–0.38
    static let opacityMin  = 0.18
    static let opacityMax  = 0.38
    static let pulsePeriod = 2.4   // seconds

    init(driverType: KoboldDriverType) {
        self.driverType = driverType
        KoboldSession.shared = self   // register as process-wide shared reference
        startOpacityPulse()
    }

    deinit { opacityTimer?.invalidate() }

    // MARK: - Events

    func receiveKnock(onResponse: @escaping (String) -> Void,
                      onDone: @escaping () -> Void) {
        show(action: .knock)
        driverType.driver.respond(
            context: "You knock. The crew inside stirs.",
            gameState: .default,
            onToken: onResponse,
            onComplete: { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.dismiss()
                    onDone()
                }
            }
        )
    }

    func receiveNote(onResponse: @escaping (String) -> Void,
                     onDone: @escaping () -> Void) {
        show(action: .slipNote)
        driverType.driver.respond(
            context: "You slip a note under the door. What does it say?",
            gameState: .default,
            onToken: onResponse,
            onComplete: { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.dismiss()
                    onDone()
                }
            }
        )
    }

    /// Injects viewer-supplied text directly as a Kobold note, bypassing AI generation.
    /// Called by TwitchChatBridge for `!request [text]` commands.
    func slipNote(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        show(action: .slipNote)
        noteInjectionHandler?(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismiss()
        }
    }

    func dismiss() {
        isVisible     = false
        currentAction = .idle
    }

    // MARK: - Private

    private func show(action: KoboldAction) {
        isVisible     = true
        currentAction = action
    }

    private func startOpacityPulse() {
        opacityTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += (1.0 / 60.0) / Self.pulsePeriod * 2 * .pi
            let t = (sin(self.phase) + 1) / 2
            self.opacity = Self.opacityMin + t * (Self.opacityMax - Self.opacityMin)
        }
    }
}

// MARK: - WebSocket stub for human-driven kobold
class WebSocketKoboldConnection: KoboldDriver {
    let name: String
    private var task: URLSessionWebSocketTask?

    init(name: String = "HumanKobold", serverURL: URL? = nil) {
        self.name = name
        if let url = serverURL {
            task = URLSession.shared.webSocketTask(with: url)
            task?.resume()
        }
    }

    func respond(
        context: String,
        gameState: GameState,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        guard let task else {
            onToken("[kobold: no WebSocket connected]")
            onComplete()
            return
        }
        task.receive { result in
            switch result {
            case .success(.string(let text)):
                DispatchQueue.main.async { onToken(text); onComplete() }
            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { onToken(text); onComplete() }
                }
            default:
                DispatchQueue.main.async { onComplete() }
            }
        }
    }
}
