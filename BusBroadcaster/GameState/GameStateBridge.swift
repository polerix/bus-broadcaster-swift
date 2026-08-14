import Foundation
import Combine

/// Polls GET localhost:8765/state every 2 seconds and publishes decoded GameState.
/// Falls back to simulated data when the JS game server is not running.
class GameStateBridge: ObservableObject {

    // MARK: - Shared singleton reference (set in init, weak to avoid cycle)
    static weak var shared: GameStateBridge?

    @Published var state:       GameState = .default
    @Published var isConnected: Bool      = false

    private var timer:           AnyCancellable?
    private let stateURL = URL(string: "http://localhost:8765/state")!
    private var simulationPhase: Double = 0

    init() {
        GameStateBridge.shared = self
        startPolling()
    }

    func startPolling() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchState() }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }

    private func fetchState() {
        let task = URLSession.shared.dataTask(with: stateURL) { [weak self] data, response, error in
            guard let self else { return }
            if let data, error == nil,
               let decoded = try? JSONDecoder().decode(GameState.self, from: data) {
                DispatchQueue.main.async {
                    self.state = decoded
                    self.isConnected = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.tickSimulation()
                }
            }
        }
        task.resume()
    }

    /// Gentle simulation so the UI has movement when the JS game isn't running
    private func tickSimulation() {
        simulationPhase += 0.05
        let heatWave  = 30.0 + 25.0 * sin(simulationPhase * 0.7)
        let sigWave   = 55.0 + 20.0 * cos(simulationPhase * 0.4)
        let fuelWave  = max(10, state.fuel  - 0.3)
        let partsWave = max(20, state.parts - 0.1)
        state = GameState(heat: heatWave, signal: sigWave,
                          fuel: fuelWave, parts: partsWave,
                          currentSong: state.currentSong)
    }

    // MARK: - Viewer command actions

    /// Temporarily boosts signal by `delta`, letting natural polling restore it
    /// after `duration` seconds.
    func temporaryBoost(signal delta: Double, duration: TimeInterval) {
        state.signal = min(100, state.signal + delta)
        // Natural polling will correct the value; no explicit rollback needed.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            // Nudge back toward natural value if still elevated
            self.state.signal = max(0, self.state.signal - delta)
        }
    }

    /// Applies a heat delta clamped to [0, 100].
    func applyDelta(heat delta: Double) {
        state.heat = min(100, max(0, state.heat + delta))
    }
}
