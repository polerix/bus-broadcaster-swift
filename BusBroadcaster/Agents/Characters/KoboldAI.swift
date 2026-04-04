import Foundation

/// AI-driven Kobold sleeve, runs apfel directly (bypasses ApfelSession
/// since Kobold isn't a full AgentCharacter).
final class KoboldAI: KoboldDriver {
    let name = "Kobold"

    private let apfelPath = NSHomeDirectory() + "/bin/apfel"

    private let systemPrompt = """
    You are a Kobold — one of the shadowy, liminal figures who drift near the Bus \
    Broadcaster. You are not quite human, not quite malevolent. You operate by a \
    different logic: knock three times for interest, slip a note for a deal, appear \
    at windows like a reflection that shouldn't be there. You speak in riddles and \
    fragmented offers. You trade in strange goods: a frequency nobody uses, a rumor \
    about a cop's schedule, a battery cell from somewhere else. You want something \
    but you don't always say what. You are plural and singular. You are barely there.

    Maximum 1–2 cryptic sentences. No exposition. Stay in character.
    """

    func respond(
        context: String,
        gameState: GameState,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        guard FileManager.default.fileExists(atPath: apfelPath) else {
            onToken("[the kobold whispers inaudibly]")
            onComplete()
            return
        }

        let proc      = Process()
        let stdinPipe = Pipe()
        let outPipe   = Pipe()

        proc.executableURL  = URL(fileURLWithPath: apfelPath)
        proc.arguments      = ["--stream"]
        proc.standardInput  = stdinPipe
        proc.standardOutput = outPipe
        proc.standardError  = Pipe()

        let prompt = "SYSTEM: \(systemPrompt)\n\n[heat=\(Int(gameState.heat))%, signal=\(Int(gameState.signal))dB]\n\n\(context)\n"

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                outPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { onComplete() }
                return
            }
            if let tok = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onToken(tok) }
            }
        }

        proc.terminationHandler = { _ in
            outPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { onComplete() }
        }

        do {
            try proc.run()
            stdinPipe.fileHandleForWriting.write(Data(prompt.utf8))
            stdinPipe.fileHandleForWriting.closeFile()
        } catch {
            onToken("[the kobold fails to materialise: \(error.localizedDescription)]")
            onComplete()
        }
    }
}
