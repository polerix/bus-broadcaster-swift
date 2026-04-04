import Foundation

/// Wraps `~/bin/apfel --stream` as a subprocess per character.
/// Writes a combined system+context prompt to stdin, reads streamed tokens from stdout.
class ApfelSession {
    let character: any AgentCharacter
    private var process: Process?
    private let apfelPath = (NSString("~/bin/apfel") as String)
        .replacingOccurrences(of: "~", with: NSHomeDirectory())

    init(character: any AgentCharacter) {
        self.character = character
    }

    /// Spawn apfel, stream tokens via `onToken`, call `onComplete` when done.
    func generate(
        context: String,
        gameState: GameState,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        cancel() // kill any previous run

        guard FileManager.default.fileExists(atPath: apfelPath) else {
            onToken("[apfel not found — place binary at ~/bin/apfel]")
            onComplete()
            return
        }

        let stateContext = buildStateContext(gameState)
        let fullPrompt   = "SYSTEM: \(character.systemPrompt)\n\n\(stateContext)\n\n\(context)\n"

        let proc         = Process()
        let stdinPipe    = Pipe()
        let stdoutPipe   = Pipe()

        proc.executableURL  = URL(fileURLWithPath: apfelPath)
        proc.arguments      = ["--stream"]
        proc.standardInput  = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError  = Pipe() // swallow stderr

        // Stream stdout tokens
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { onComplete() }
                return
            }
            if let token = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onToken(token) }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { onComplete() }
            self?.process = nil
        }

        do {
            try proc.run()
            self.process = proc
            stdinPipe.fileHandleForWriting.write(Data(fullPrompt.utf8))
            stdinPipe.fileHandleForWriting.closeFile()
        } catch {
            onToken("[Error launching apfel: \(error.localizedDescription)]")
            onComplete()
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
    }

    // MARK: - Private helpers

    private func buildStateContext(_ gs: GameState) -> String {
        var parts = [
            "heat=\(Int(gs.heat))%",
            "signal=\(Int(gs.signal))dB",
            "fuel=\(Int(gs.fuel))%",
            "parts=\(Int(gs.parts))%",
        ]
        if let song = gs.currentSong { parts.append("playing: \"\(song)\"") }
        return "[Game State: \(parts.joined(separator: ", "))]"
    }
}
