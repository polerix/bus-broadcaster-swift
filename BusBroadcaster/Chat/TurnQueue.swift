import Foundation
import Combine

class TurnQueue: ObservableObject {

    // MARK: - Shared singleton reference (set on init, weak to avoid cycle)
    static weak var shared: TurnQueue?

    @Published var messages:          [ChatMessage]  = []
    @Published var isRunning:         Bool           = false
    @Published var currentSpeaker:    String?        = nil
    @Published var workActivities:    [WorkActivity] = []
    @Published var koboldInventory:   [KoboldItem]   = []
    @Published var koboldAcknowledged:      Bool          = false
    @Published var isInternalSpeakerActive: Bool          = false
    @Published var internalMessages:        [ChatMessage] = []
    @Published var cameraStations:          [WorkActivity] = []

    /// Set to true by TwitchChatBridge when a subscriber/VIP sends a message.
    /// Consumed once by pickNextSpeaker() to apply a ×1.3 arousal-weighted boost.
    var twitchBoostPending: Bool = false

    private let insideVan: [any AgentCharacter] = [
        Dolores(), Soren(), Priya(), Marcus(), Yael(), Felix()
    ]
    private let outsideVan: [any AgentCharacter] = [
        DetectiveMorrow(), Prophet(), Nadia()
    ]

    private var sessions:          [String: ApfelSession] = [:]
    private var koboldSession:     KoboldSession?
    private var gameState:         GameState = .default
    private var isKoboldBlocking:  Bool = false
    private var nextSpeakTask:     DispatchWorkItem?
    private weak var bridge:       GameStateBridge?
    private var bridgeCancellable: AnyCancellable?

    // Active governors — one per in-flight generation
    private var governors: [UUID: Governor] = [:]

    let moodRegistry   = MoodRegistry()
    let contentFetcher = ContentFetcher()

    private let speech = SpeechManager.shared

    /// Rolling story memory — prevents repetition, advances the arc.
    private let memory = StoryMemory()

    // MARK: - Init

    init() {
        TurnQueue.shared = self

        for char in insideVan + outsideVan {
            sessions[char.name] = ApfelSession(character: char)
        }

        koboldSession = KoboldSession(driverType: .ai(KoboldAI()))

        // Register shared references for Twitch command dispatch
        MoodRegistry.shared = moodRegistry
        koboldSession?.noteInjectionHandler = { [weak self] text in
            self?.leaveKoboldNote(text)
        }
    }

    func connect(bridge: GameStateBridge) {
        self.bridge = bridge
        bridgeCancellable = bridge.$state.sink { [weak self] state in
            self?.gameState = state
        }
        if !isRunning { start() }
    }

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        isRunning = true

        BusPlayer.shared.start()

        DispatchQueue.global(qos: .background).async {
            PhraseBank.shared.warmUp()
        }

        let greeting = ChatMessage(character: "Dolores",
                                   text: "Signal check. Everyone online?",
                                   timestamp: Date())
        messages.append(greeting)

        speech.preSynthesize("Signal check. Everyone online?", as: "Dolores")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.speech.speak("Signal check. Everyone online?", as: "Dolores")
        }
        scheduleNext(after: Governor.nextSpeakerDelay(for: "Dolores",
                                                      text: "Signal check. Everyone online?"))
    }

    func restart() { stop(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.start() } }

    func stop() {
        isRunning = false
        currentSpeaker = nil
        nextSpeakTask?.cancel()
        sessions.values.forEach { $0.cancel() }
        governors.values.forEach { $0.cancel() }
        governors.removeAll()
        speech.stop()
        BusPlayer.shared.stop()
        memory.reset()
        workActivities.removeAll()
    }

    func update(gameState: GameState) {
        self.gameState = gameState
        moodRegistry.updateFromGameState(gameState, koboldActive: isKoboldBlocking)
    }

    // MARK: - Twitch viewer integration

    /// Called by TwitchChatBridge when a subscriber or VIP sends a message.
    /// Boosts high-arousal characters' selection weight by ×1.3 for one turn.
    func applyTwitchBoost() {
        twitchBoostPending = true
    }

    // MARK: - Kobold

    func triggerKoboldKnock() {
        guard !isKoboldBlocking else { return }
        isKoboldBlocking = true
        nextSpeakTask?.cancel()
        messages.append(ChatMessage(character: "Kobold",
                                    text: KoboldAction.knock.chatLabel,
                                    timestamp: Date()))
        koboldSession?.receiveKnock(
            onResponse: { [weak self] token in self?.appendOrStream(to: "Kobold", token: token) },
            onDone: { [weak self] in
                guard let self else { return }
                self.isKoboldBlocking = false
                if let idx = self.messages.lastIndex(where: { $0.character == "Kobold" }) {
                    self.speech.speak(self.messages[idx].text, as: "Kobold")
                }
                if self.isRunning { self.scheduleNext(after: 3.0) }
            }
        )
    }

    func triggerKoboldNote() {
        guard !isKoboldBlocking else { return }
        isKoboldBlocking = true
        nextSpeakTask?.cancel()
        messages.append(ChatMessage(character: "Kobold",
                                    text: KoboldAction.slipNote.chatLabel,
                                    timestamp: Date()))
        koboldSession?.receiveNote(
            onResponse: { [weak self] token in self?.appendOrStream(to: "Kobold", token: token) },
            onDone: { [weak self] in
                guard let self else { return }
                self.isKoboldBlocking = false
                if let idx = self.messages.lastIndex(where: { $0.character == "Kobold" }) {
                    self.speech.speak(self.messages[idx].text, as: "Kobold")
                }
                if self.isRunning { self.scheduleNext(after: 3.0) }
            }
        )
    }

    // MARK: - Speaker selection

    func pickNextSpeaker() -> (any AgentCharacter)? {
        var candidates: [(any AgentCharacter, Double)] = []

        for char in insideVan {
            var w = 1.0
            switch char.name {
            case "Marcus", "Felix": w += gameState.heat / 50.0
            case "Priya":           w += max(0, (100 - gameState.signal) / 50.0)
            case "Yael":            w += max(0, (100 - gameState.parts)  / 60.0)
            case "Soren":           w += gameState.signal / 80.0
            default: break
            }
            w *= moodRegistry.speakWeight(for: char.name)
            candidates.append((char, max(0.05, w)))
        }

        candidates.append((Prophet(), 0.4 * moodRegistry.speakWeight(for: "Prophet")))
        candidates.append((Nadia(),   0.4 * moodRegistry.speakWeight(for: "Nadia")))

        if gameState.isDetectiveThreat {
            candidates.append((DetectiveMorrow(), 2.0 * moodRegistry.speakWeight(for: "Detective Morrow")))
        }

        // Twitch subscriber/VIP boost: high-arousal characters get ×1.3 for one turn
        if twitchBoostPending {
            twitchBoostPending = false
            candidates = candidates.map { char, w in
                let boost = moodRegistry.mood(for: char.name).arousal > 6 ? 1.3 : 1.0
                return (char, w * boost)
            }
        }

        let total = candidates.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return candidates.first?.0 }
        var roll = Double.random(in: 0..<total)
        for (char, weight) in candidates {
            roll -= weight; if roll <= 0 { return char }
        }
        return candidates.first?.0
    }

    // MARK: - Work activities

    private func makeActivity(for char: any AgentCharacter) -> WorkActivity {
        var aType = WorkActivity.makeType(for: char.name)
        if case .videoPreview = aType, let url = GrimoireLibrary.randomVideoURL() {
            aType = .videoPreview(path: url.path)
        }
        return WorkActivity(character: char.name, type: aType)
    }

    private func closeActivity(_ id: UUID, after delay: Double) {
        if let idx = workActivities.firstIndex(where: { $0.id == id }) {
            workActivities[idx].isActive = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.workActivities.removeAll { $0.id == id }
        }
    }

    // MARK: - Scheduling

    private func scheduleNext(after delay: Double) {
        let task = DispatchWorkItem { [weak self] in self?.speakNext() }
        nextSpeakTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func speakNext() {
        guard isRunning, !isKoboldBlocking else { return }
        guard let char = pickNextSpeaker() else { scheduleNext(after: 4.0); return }

        let session = sessions[char.name] ?? {
            let s = ApfelSession(character: char); sessions[char.name] = s; return s
        }()

        currentSpeaker = char.name

        let activity   = makeActivity(for: char)
        workActivities.append(activity)
        let activityID = activity.id

        let streamMsg = ChatMessage(character: char.name, text: "", timestamp: Date(), isStreaming: true)
        messages.append(streamMsg)
        let msgID = streamMsg.id

        let recentContext = messages.suffix(8)
            .filter { !$0.text.isEmpty }
            .map { "\($0.character): \($0.text)" }.joined(separator: "\n")

        let memoryContext = memory.contextBlock(for: char.name)
        var prompt: String
        if recentContext.isEmpty {
            prompt = "Open with a brief in-character observation about the current broadcast situation."
        } else {
            prompt = "Continue the conversation naturally. Keep it brief (1–3 sentences)."
            if !memoryContext.isEmpty { prompt += "\n\n\(memoryContext)" }
            prompt += "\n\n---\n\(recentContext)"
        }

        if moodRegistry.isFragmented(name: char.name) {
            prompt += "\n\n[Internal state: highly agitated — one short fragmented burst only.]"
        }

        let govID    = msgID
        let governor = Governor(
            character: char.name,
            onChar: { [weak self] ch in
                guard let self,
                      let idx = self.messages.firstIndex(where: { $0.id == msgID }) else { return }
                self.messages[idx].text += ch
                if let aidx = self.workActivities.firstIndex(where: { $0.id == activityID }) {
                    self.workActivities[aidx].displayText = self.messages[idx].text
                }
            },
            onTextKnown: { [weak self] fullText in
                let clean = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return }
                self?.speech.preSynthesize(clean, as: char.name)
            },
            onDrained: { [weak self] finalText in
                guard let self else { return }
                if let idx = self.messages.firstIndex(where: { $0.id == msgID }) {
                    self.messages[idx].isStreaming = false
                    let text = self.messages[idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty { self.messages[idx].text = "[…]" }
                }
                let text = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && text != "[…]" {
                    self.memory.record(character: char.name, text: text)
                }
                self.moodRegistry.processSpeech(characterName: char.name, text: text)
                if text.localizedCaseInsensitiveContains("kobold") && !self.koboldAcknowledged {
                    self.koboldAcknowledged = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                        self?.koboldAcknowledged = false
                    }
                }
                self.speech.speak(text.isEmpty ? "[…]" : text, as: char.name)
                let nextDelay = Governor.nextSpeakerDelay(for: char.name, text: text)
                self.closeActivity(activityID, after: nextDelay * 0.8)
                self.currentSpeaker = nil
                self.governors[govID] = nil
                if self.isRunning { self.scheduleNext(after: nextDelay) }
            }
        )
        governors[govID] = governor

        let webContent = contentFetcher.currentSummary()
        session.generate(context: prompt, gameState: gameState, webContent: webContent,
            onToken:    { [weak self] token in self?.governors[govID]?.feed(token) },
            onComplete: { [weak self] in  self?.governors[govID]?.generationComplete() }
        )
    }

    // MARK: - Kobold user actions

    func sendKoboldChat(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let msg = ChatMessage(character: "Kobold", text: text, timestamp: Date())
        messages.append(msg)
        speech.speak(text, as: "Kobold")
        koboldAcknowledged = true
    }

    func leaveKoboldNote(_ text: String, location: String = "unknown", persists: String = "∞") {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let envelope = "*a folded note appears* \(text)"
        let msg = ChatMessage(character: "Kobold", text: envelope, timestamp: Date())
        messages.append(msg)
        speech.speak(text, as: "Kobold")
    }

    func addToKoboldCache(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        koboldInventory.append(KoboldItem(name: name))
        let msg = ChatMessage(character: "Kobold",
                              text: "*\(name) materialises at the threshold*",
                              timestamp: Date())
        messages.append(msg)
    }

    func removeFromKoboldCache(id: UUID) {
        guard let idx = koboldInventory.firstIndex(where: { $0.id == id }) else { return }
        let name = koboldInventory.remove(at: idx).name
        let msg = ChatMessage(character: "Kobold",
                              text: "*\(name) is no longer where it was*",
                              timestamp: Date())
        messages.append(msg)
    }

    // MARK: - Kobold stream helper
    private func appendOrStream(to name: String, token: String) {
        if let idx = messages.lastIndex(where: { $0.character == name && $0.isStreaming }) {
            messages[idx].text += token
        } else {
            messages.append(ChatMessage(character: name, text: token,
                                        timestamp: Date(), isStreaming: true))
        }
    }
}
