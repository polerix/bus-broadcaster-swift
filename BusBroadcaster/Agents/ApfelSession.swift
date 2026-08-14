import Foundation

/// Wraps `~/bin/apfel --stream` as a subprocess per character.
/// Passes system prompt via -s and user context as the positional argument — apfel does NOT read stdin.
class ApfelSession {
    let character: any AgentCharacter
    private var process: Process?
    private let apfelPath = (NSString("~/bin/apfel") as String)
        .replacingOccurrences(of: "~", with: NSHomeDirectory())

    init(character: any AgentCharacter) {
        self.character = character
    }

    func generate(
        context: String,
        gameState: GameState,
        webContent: String = "",
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        cancel()

        guard FileManager.default.fileExists(atPath: apfelPath) else {
            onToken("[apfel not found — place binary at ~/bin/apfel]")
            onComplete()
            return
        }

        let stateContext = buildStateContext(gameState)
        var webSection = ""
        if !webContent.isEmpty {
            webSection = "\n\n[LIVE INTEL — use sparingly, only if relevant to your character's role]\n\(webContent)"
        }
        // System prompt: character identity + bus status + live intel
        let systemPrompt = "\(character.systemPrompt)\n\n\(stateContext)\(webSection)"
        // User-turn: the conversation context / cue
        let userPrompt = context

        let proc       = Process()
        let stdoutPipe = Pipe()

        proc.executableURL  = URL(fileURLWithPath: apfelPath)
        // apfel --stream takes the prompt as a positional arg; -s sets the system prompt.
        // --permissive avoids content-filter refusals on edgy radio content.
        proc.arguments      = ["--stream", "--permissive", "-s", systemPrompt, userPrompt]
        proc.standardInput  = nil          // apfel does not read stdin
        proc.standardOutput = stdoutPipe
        proc.standardError  = Pipe()       // swallow stderr noise

        // Guard against double-firing: readabilityHandler (empty data) AND
        // terminationHandler both dispatch onComplete — we only want one call.
        let lock = NSLock()
        var completed = false
        let fireOnce: () -> Void = {
            lock.lock()
            let first = !completed
            completed = true
            lock.unlock()
            if first {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { onComplete() }
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                fireOnce()
                return
            }
            if let token = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onToken(token) }
            }
        }

        // Do NOT mutate self.process here — doing so while NSTask is on a
        // background queue causes a setTerminationHandler: crash on dealloc.
        proc.terminationHandler = { _ in
            fireOnce()
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            onToken("[Error launching apfel: \(error.localizedDescription)]")
            onComplete()
        }
    }

    func cancel() {
        // Clear the handler BEFORE terminate so it doesn't fire on cancellation,
        // and to avoid NSTask touching a nil'd block during dealloc on BG queue.
        process?.terminationHandler = nil
        process?.standardOutput.flatMap { $0 as? Pipe }?
            .fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
    }

    deinit { cancel() }

    private func buildStateContext(_ gs: GameState) -> String {
        var parts = [
            "heat=\(Int(gs.heat))%",
            "signal=\(Int(gs.signal))dB",
            "fuel=\(Int(gs.fuel))%",
            "parts=\(Int(gs.parts))%",
        ]
        if let song = gs.currentSong { parts.append("playing: \"\(song)\"") }
        return "[BUS STATUS: \(parts.joined(separator: ", "))]"
    }
}
