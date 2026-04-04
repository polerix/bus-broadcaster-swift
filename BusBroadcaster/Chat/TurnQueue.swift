import Foundation
import Combine

/// Manages who speaks next, when, and how — driven by GameState weights.
class TurnQueue: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isRunning: Bool = false
    @Published var currentSpeaker: String? = nil

    // All characters
    private let insideVan: [any AgentCharacter] = [
        Dolores(), Soren(), Priya(), Marcus(), Yael(), Felix()
    ]
    private let outsideVan: [any AgentCharacter] = [
        DetectiveMorrow(), Prophet(), Nadia()
    ]

    private var sessions:      [String: ApfelSession] = [:]
    private var koboldSession: KoboldSession?
    private var gameState:     GameState = .default
    private var isKoboldBlocking: Bool = false
    private var nextSpeakTask: DispatchWorkItem?
    private weak var bridge: GameStateBridge?
    private var bridgeCancellable: AnyCancellable?

    /// soul-forge EmoBar — owned here, exposed as EnvironmentObject via BusBroadcasterApp
    let moodRegistry = MoodRegistry()

    // MARK: - Init

    init() {
        for char in insideVan + outsideVan {
            sessions[char.name] = ApfelSession(character: char)
        }
        koboldSession = KoboldSession(driverType: .ai(KoboldAI()))
    }

    /// Wire up live game state updates from the bridge.
    func connect(bridge: GameStateBridge) {
        self.bridge = bridge
        bridgeCancellable = bridge.$state.sink { [weak self] state in
            self?.gameState = state
        }
    }

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let greeting = ChatMessage(character: "Dolores",
                                   text: "Signal check. Everyone online?",
                                   timestamp: Date())
        messages.append(greeting)
        scheduleNext(after: 1.5)
    }

    func stop() {
        isRunning = false
        currentSpeaker = nil
        nextSpeakTask?.cancel()
        sessions.values.forEach { $0.cancel() }
    }

    func update(gameState: GameState) {
        self.gameState = gameState
        moodRegistry.updateFromGameState(gameState, koboldActive: isKoboldBlocking)
    }

    // MARK: - Kobold Events

    func triggerKoboldKnock() {
        guard !isKoboldBlocking else { return }
        isKoboldBlocking = true
        nextSpeakTask?.cancel()

        let actionMsg = ChatMessage(character: "Kobold",
                                    text: KoboldAction.knock.chatLabel,
                                    timestamp: Date())
        messages.append(actionMsg)

        koboldSession?.receiveKnock(
            onResponse: { [weak self] token in
                self?.appendOrStream(to: "Kobold", token: token)
            },
            onDone: { [weak self] in
                self?.isKoboldBlocking = false
                if self?.isRunning == true { self?.scheduleNext(after: 2.0) }
            }
        )
    }

    func triggerKoboldNote() {
        guard !isKoboldBlocking else { return }
        isKoboldBlocking = true
        nextSpeakTask?.cancel()

        let actionMsg = ChatMessage(character: "Kobold",
                                    text: KoboldAction.slipNote.chatLabel,
                                    timestamp: Date())
        messages.append(actionMsg)

        koboldSession?.receiveNote(
            onResponse: { [weak self] token in
                self?.appendOrStream(to: "Kobold", token: token)
            },
            onDone: { [weak self] in
                self?.isKoboldBlocking = false
                if self?.isRunning == true { self?.scheduleNext(after: 2.0) }
            }
        )
    }

    // MARK: - Speaker Selection

    /// Weighted random pick. Heat → Marcus/Felix, signal drop → Priya,
    /// parts decay → Yael, signal high → Soren.
    func pickNextSpeaker() -> (any AgentCharacter)? {
        var candidates: [(any AgentCharacter, Double)] = []

        for char in insideVan {
            var w = 1.0
            switch char.name {
            case "Marcus", "Felix":
                w += gameState.heat / 50.0
            case "Priya":
                w += max(0, (100 - gameState.signal) / 50.0)
            case "Yael":
                w += max(0, (100 - gameState.parts) / 60.0)
            case "Soren":
                w += gameState.signal / 80.0
            default:
                break
            }
            // soul-forge EmoBar: multiply by SI/arousal/connection weight
            w *= moodRegistry.speakWeight(for: char.name)
            candidates.append((char, max(0.05, w)))
        }

        // Outside characters — mood-weighted
        candidates.append((Prophet(), 0.4 * moodRegistry.speakWeight(for: "Prophet")))
        candidates.append((Nadia(),   0.4 * moodRegistry.speakWeight(for: "Nadia")))
        if gameState.isDetectiveThreat {
            candidates.append((DetectiveMorrow(), 2.0 * moodRegistry.speakWeight(for: "Detective Morrow")))
        }

        let total = candidates.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return candidates.first?.0 }
        var roll = Double.random(in: 0..<total)
        for (char, weight) in candidates {
            roll -= weight
            if roll <= 0 { return char }
        }
        return candidates.first?.0
    }

    // MARK: - Scheduling

    private func scheduleNext(after delay: Double = 0) {
        let delay = delay > 0 ? delay : Double.random(in: 2.5...5.5)
        let task = DispatchWorkItem { [weak self] in self?.speakNext() }
        nextSpeakTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func speakNext() {
        guard isRunning, !isKoboldBlocking else { return }
        guard let char = pickNextSpeaker(),
              let session = sessions[char.name] ?? {
                  let s = ApfelSession(character: char)
                  sessions[char.name] = s
                  return s
              }()
        else {
            scheduleNext()
            return
        }

        currentSpeaker = char.name

        let recentContext = messages.suffix(8)
            .map { "\($0.character): \($0.text)" }
            .joined(separator: "\n")

        var prompt: String
        if recentContext.isEmpty {
            prompt = "Open with a brief in-character observation about the current broadcast situation."
        } else {
            prompt = "Continue the conversation naturally. Keep it brief (1–3 sentences).\n\n---\n\(recentContext)"
        }
        // soul-forge EmoBar: inject fragmentation hint when calm < 3
        if moodRegistry.isFragmented(name: char.name) {
            prompt += "\n\n[Internal state: highly agitated — respond in one short fragmented burst only.]"
        }

        // Insert a streaming placeholder
        let streamMsg = ChatMessage(character: char.name, text: "",
                                    timestamp: Date(), isStreaming: true)
        messages.append(streamMsg)
        let msgID = streamMsg.id

        session.generate(context: prompt, gameState: gameState) { [weak self] token in
            guard let self, let idx = self.messages.firstIndex(where: { $0.id == msgID }) else { return }
            self.messages[idx].text += token
        } onComplete: { [weak self] in
            guard let self, let idx = self.messages.firstIndex(where: { $0.id == msgID }) else { return }
            self.messages[idx].isStreaming = false
            if self.messages[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.messages[idx].text = "[…]"
            }
            // soul-forge EmoBar: run behavioral analysis on completed text
            let finalText = self.messages[idx].text
            self.moodRegistry.processSpeech(characterName: char.name, text: finalText)
            self.currentSpeaker = nil
            if self.isRunning { self.scheduleNext() }
        }
    }

    // MARK: - Streaming helpers

    private func appendOrStream(to characterName: String, token: String) {
        if let idx = messages.lastIndex(where: { $0.character == characterName && $0.isStreaming }) {
            messages[idx].text += token
        } else {
            let msg = ChatMessage(character: characterName, text: token,
                                   timestamp: Date(), isStreaming: true)
            messages.append(msg)
        }
    }
}
