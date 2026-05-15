import Foundation

/// The orchestration layer: drives the one-per-second tick loop and publishes
/// `Room_State` and `PhaseTransition` events via `AsyncStream`.
///
/// All mutable state is actor-isolated. Construct one instance per app session;
/// the engine is not designed to be restarted after `stop()`.
public actor TimerEngine {

    // MARK: - Public streams

    /// A continuous stream of `Room_State` snapshots, emitted at most once per second.
    /// Buffers the newest value only; a slow consumer always receives the latest state.
    public nonisolated let stateStream:      AsyncStream<Room_State>
    /// Emits a `PhaseTransition` whenever the timer crosses a phase boundary.
    public nonisolated let transitionStream: AsyncStream<PhaseTransition>

    // MARK: - Private state

    private let stateContinuation:      AsyncStream<Room_State>.Continuation
    private let transitionContinuation: AsyncStream<PhaseTransition>.Continuation

    private var tickTask:      Task<Void, Never>?
    private var roomOffset:    TimeInterval = 0
    private var serverJoinTime: TimeInterval = 0
    private var nowAtJoin:     TimeInterval = 0
    private var config:        Configuration = .default
    private var storage:       SharedStorage

    // MARK: - Init

    /// Creates a `TimerEngine`.
    ///
    /// - Parameter storage: The persistence layer. Defaults to the shared App Group store.
    ///   Pass a test-isolated instance in unit tests.
    public init(storage: SharedStorage = .shared) {
        // Wire up both streams before `self` is fully initialised.
        var stateCont:      AsyncStream<Room_State>.Continuation!
        var transitionCont: AsyncStream<PhaseTransition>.Continuation!

        self.stateStream = AsyncStream(Room_State.self, bufferingPolicy: .bufferingNewest(1)) {
            stateCont = $0
        }
        self.transitionStream = AsyncStream(PhaseTransition.self, bufferingPolicy: .bufferingNewest(1)) {
            transitionCont = $0
        }

        self.stateContinuation      = stateCont
        self.transitionContinuation = transitionCont
        self.storage                = storage
    }

    // MARK: - Lifecycle

    /// Validates `config`, persists the offset, and starts the tick loop.
    ///
    /// Calling `start` on an already-running engine cancels the previous tick loop
    /// and immediately begins a new one with the supplied parameters.
    ///
    /// - Throws: `ConfigurationError` when `config` fails validation.
    public func start(
        offset:         TimeInterval,
        serverJoinTime: TimeInterval,
        config:         Configuration
    ) throws {
        if let error = TimerCalculator.validate(config) { throw error }

        tickTask?.cancel()

        self.roomOffset     = offset
        self.serverJoinTime = serverJoinTime
        self.nowAtJoin      = Date().timeIntervalSince1970
        self.config         = config

        try storage.writeOffset(offset, serverJoinTime: serverJoinTime)
        storage.write(config)

        tickTask = Task { [weak self] in await self?.tickLoop() }
    }

    /// Cancels the tick loop, clears persisted offset, and finishes both streams.
    public func stop() {
        tickTask?.cancel()
        tickTask = nil
        storage.clearOffset()
        stateContinuation.finish()
        transitionContinuation.finish()
    }

    // MARK: - Restore on launch

    /// Attempts to resume from a previously persisted session.
    ///
    /// Call this once during app launch. If both offset and config are found in storage
    /// the engine starts immediately without a server round-trip. If either is missing
    /// the engine remains idle.
    public func restoreIfNeeded() {
        guard let offset     = storage.readOffset(),
              let joinTime   = storage.readServerJoinTime(),
              let savedConfig = storage.readConfig() else { return }
        try? start(offset: offset, serverJoinTime: joinTime, config: savedConfig)
    }

    // MARK: - Tick loop

    private func tickLoop() async {
        var previousTime:  TimeInterval = Date().timeIntervalSince1970
        var previousPhase: Phase = TimerCalculator.computeState(
            offset: roomOffset, config: config, at: previousTime
        ).currentPhase

        // Emit the current state immediately (satisfies Req 4.3).
        emitTick(at: previousTime, previousTime: previousTime, previousPhase: &previousPhase)

        while !Task.isCancelled {
            // Sleep until the next whole-second boundary.
            let now         = Date().timeIntervalSince1970
            let nextBoundary = floor(now) + 1.0
            let nanoseconds  = UInt64(max(0, nextBoundary - now) * 1_000_000_000)

            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                break   // CancellationError — exit cleanly
            }

            guard !Task.isCancelled else { break }

            let tickTime = Date().timeIntervalSince1970
            emitTick(at: tickTime, previousTime: previousTime, previousPhase: &previousPhase)
            previousTime = tickTime
        }
    }

    private func emitTick(
        at currentTime:         TimeInterval,
        previousTime:           TimeInterval,
        previousPhase: inout Phase
    ) {
        let skew = TimerCalculator.computeSkewWarning(
            currentTime:    currentTime,
            roomOffset:     roomOffset,
            nowAtJoin:      nowAtJoin,
            serverJoinTime: serverJoinTime
        )

        var state = TimerCalculator.computeState(
            offset: roomOffset, config: config, at: currentTime
        )
        state.clockSkewWarning = skew

        stateContinuation.yield(state)
        storage.write(state)
        storage.write(config)

        // Phase transitions
        let transitions = TimerCalculator.collectTransitions(
            prevTime:   previousTime,
            currTime:   currentTime,
            roomOffset: roomOffset,
            config:     config,
            detectedAt: Date()
        )
        for t in transitions {
            transitionContinuation.yield(t)
        }

        previousPhase = state.currentPhase
    }
}
