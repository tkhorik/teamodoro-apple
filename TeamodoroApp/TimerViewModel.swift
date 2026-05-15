import Foundation
import Observation
import SynchronizedTimerCore

@Observable
@MainActor
final class TimerViewModel {

    // MARK: - Published state (drives SwiftUI)

    private(set) var currentPhase:    Phase    = .work
    private(set) var remainingSeconds: Int     = 1_500
    private(set) var cycleIndex:      Int      = 0
    private(set) var clockSkewWarning: Bool    = false
    private(set) var isRunning:       Bool     = false

    // MARK: - Session info

    let config: Configuration = .default
    private(set) var roomOffset:    TimeInterval = 0
    private(set) var roomName:      String       = "SOLO MODE"
    private(set) var memberCount:   Int          = 1

    // MARK: - Computed

    /// Elapsed seconds within the current cycle — used to position the ring dot.
    var cyclePosition: TimeInterval {
        guard isRunning, roomOffset > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince1970 - roomOffset
        return max(0, elapsed).truncatingRemainder(dividingBy: config.cycleDuration)
    }

    // MARK: - Private

    private let engine:    TimerEngine
    private var stateTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        let storage = SharedStorage()
        engine = TimerEngine(storage: storage)
        // Attempt to restore a previous session (e.g. after app backgrounding).
        Task { await engine.restoreIfNeeded() }
    }

    // MARK: - Session control

    /// Starts a local solo session anchored to the current second.
    func startSoloSession() {
        let offset = Date().timeIntervalSince1970
        roomOffset  = offset
        roomName    = "SOLO MODE"
        memberCount = 1
        isRunning   = true
        Task {
            try? await engine.start(
                offset:         offset,
                serverJoinTime: offset,
                config:         config
            )
            observeStateStream()
        }
    }

    func stopSession() {
        stateTask?.cancel()
        stateTask = nil
        Task { await engine.stop() }
        isRunning = false
    }

    // MARK: - Stream observation

    private func observeStateStream() {
        stateTask?.cancel()
        stateTask = Task {
            for await state in engine.stateStream {
                currentPhase     = state.currentPhase
                remainingSeconds = state.remainingSeconds
                cycleIndex       = state.cycleIndex
                clockSkewWarning = state.clockSkewWarning
            }
            // Stream finished (engine stopped).
            isRunning = false
        }
    }
}
