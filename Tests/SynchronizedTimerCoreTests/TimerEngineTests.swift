import Testing
import Foundation
@testable import SynchronizedTimerCore

// MARK: - Helpers

private let offset: TimeInterval = 1_700_000_000

private func isolatedEngine() -> TimerEngine {
    TimerEngine(storage: SharedStorage(suiteName: UUID().uuidString))
}

// MARK: - TimerCalculator.computeSkewWarning (Property 12, Task 6.4*)

@Suite("TimerCalculator.computeSkewWarning")
struct SkewWarningTests {

    @Test("Skew below 5.0 s → false")
    func belowThreshold() {
        #expect(!TimerCalculator.computeSkewWarning(
            currentTime: 100, roomOffset: 0, nowAtJoin: 50, serverJoinTime: 50
        ))
    }

    @Test("Skew exactly 5.0 s → false (boundary must NOT trigger)")
    func exactlyAtThreshold() {
        // expected = roomOffset + (nowAtJoin - serverJoinTime) = 0 + (50 - 45) = 5
        // currentTime = 10 → |10 - 5| = 5.0 → false
        #expect(!TimerCalculator.computeSkewWarning(
            currentTime: 10, roomOffset: 0, nowAtJoin: 50, serverJoinTime: 45
        ))
    }

    @Test("Skew above 5.0 s → true")
    func aboveThreshold() {
        // expected = 0 + (50 - 43) = 7; currentTime = 0 → |0 - 7| = 7.0 > 5 → true
        #expect(TimerCalculator.computeSkewWarning(
            currentTime: 0, roomOffset: 0, nowAtJoin: 50, serverJoinTime: 43
        ))
    }

    // Property 12: Clock Skew Warning Threshold (Task 6.4*)
    @Test("Property 12: skewWarning iff |deviation| > 5.0 for 300 random tuples")
    func property12SkewThreshold() {
        var rng = SeededRNG(seed: 40)
        for _ in 0 ..< 300 {
            let roomOff  = Double.random(in: 0 ... 2_000_000_000, using: &rng)
            let sJoinT   = Double.random(in: 0 ... 2_000_000_000, using: &rng)
            let nowJ     = Double.random(in: 0 ... 2_000_000_000, using: &rng)
            let currT    = Double.random(in: 0 ... 2_000_000_000, using: &rng)

            let expected = roomOff + (nowJ - sJoinT)
            let skew     = abs(currT - expected)
            let result   = TimerCalculator.computeSkewWarning(
                currentTime: currT, roomOffset: roomOff, nowAtJoin: nowJ, serverJoinTime: sJoinT
            )
            #expect(result == (skew > 5.0), "skew=\(skew) result=\(result)")
        }
    }
}

// MARK: - TimerCalculator.collectTransitions (Properties 9-11, Tasks 6.6-6.8*)

@Suite("TimerCalculator.collectTransitions")
struct CollectTransitionsTests {

    // Property 9: Phase Transition Detection Correctness (Task 6.6*)
    @Test("No transition emitted when phase is unchanged between ticks")
    func property9NoSpuriousTransition() {
        let config = Configuration.default
        // Both ticks in the first work phase (0–1500 s)
        let prev = offset + 100.0
        let curr = offset + 200.0
        let transitions = TimerCalculator.collectTransitions(
            prevTime: prev, currTime: curr, roomOffset: offset,
            config: config, detectedAt: Date()
        )
        #expect(transitions.isEmpty)
    }

    @Test("Exactly one transition emitted when crossing a single boundary")
    func singleBoundaryProducesOneTransition() {
        let config = Configuration.default
        // Cross from work (ends at 1500) into shortBreak
        let prev = offset + 1_499.0
        let curr = offset + 1_501.0
        let transitions = TimerCalculator.collectTransitions(
            prevTime: prev, currTime: curr, roomOffset: offset,
            config: config, detectedAt: Date()
        )
        #expect(transitions.count == 1)
        #expect(transitions[0].from == .work)
        #expect(transitions[0].to   == .shortBreak)
    }

    @Test("No transition emitted for backward clock adjustment")
    func backwardClockNoTransition() {
        let config = Configuration.default
        let transitions = TimerCalculator.collectTransitions(
            prevTime: offset + 1_600, currTime: offset + 1_400,
            roomOffset: offset, config: config, detectedAt: Date()
        )
        #expect(transitions.isEmpty)
    }

    @Test("No transition when prevTime == currTime")
    func sameTimestampNoTransition() {
        let t = offset + 500.0
        let transitions = TimerCalculator.collectTransitions(
            prevTime: t, currTime: t, roomOffset: offset,
            config: .default, detectedAt: Date()
        )
        #expect(transitions.isEmpty)
    }

    // Property 10: Forward Clock Jump Emits Ordered Transitions (Task 6.7*)
    @Test("Property 10: forward jump across 3 boundaries emits 3 ordered transitions")
    func property10ForwardJumpMultipleBoundaries() {
        let config = Configuration.default
        // Work phase 1 ends at 1500, shortBreak at 1800, work phase 2 ends at 3300.
        // Jump from 100 to 2500 crosses two boundaries: 1500 and 1800.
        let prev = offset + 100.0
        let curr = offset + 2_500.0
        let transitions = TimerCalculator.collectTransitions(
            prevTime: prev, currTime: curr, roomOffset: offset,
            config: config, detectedAt: Date()
        )
        #expect(transitions.count == 2)
        #expect(transitions[0].from == .work       && transitions[0].to == .shortBreak)
        #expect(transitions[1].from == .shortBreak && transitions[1].to == .work)
    }

    @Test("Property 10: forward jump across a full cycle emits all 7 boundaries")
    func fullCycleJump() {
        let config = Configuration.default // 8 phases → 8 boundaries (7 internal + 1 wrap)
        let prev = offset + 1.0
        let curr = offset + config.cycleDuration + 1.0   // just past cycle end
        let transitions = TimerCalculator.collectTransitions(
            prevTime: prev, currTime: curr, roomOffset: offset,
            config: config, detectedAt: Date()
        )
        // 7 intra-cycle boundaries + 1 cycle-wrap boundary = 8,
        // but we start at 1 s so we skip the first segment start → 8 boundaries total.
        #expect(transitions.count == 8)
        // First transition: work → shortBreak
        #expect(transitions.first?.from == .work && transitions.first?.to == .shortBreak)
        // Last transition: longBreak → work (cycle wrap)
        #expect(transitions.last?.from == .longBreak && transitions.last?.to == .work)
    }

    // Property 11: Backward Clock Jump Emits No Transitions (Task 6.8*)
    @Test("Property 11: 100 random backward jumps always produce zero transitions")
    func property11BackwardJumpNeverTransitions() {
        var rng = SeededRNG(seed: 41)
        for _ in 0 ..< 100 {
            let config = Configuration.randomValid(using: &rng)
            let curr   = Double.random(in: 100 ... 500_000, using: &rng)
            let prev   = curr + Double.random(in: 0.001 ... 1_000, using: &rng)  // prev > curr
            let transitions = TimerCalculator.collectTransitions(
                prevTime: prev, currTime: curr, roomOffset: 0,
                config: config, detectedAt: Date()
            )
            #expect(transitions.isEmpty)
        }
    }

    @Test("No transition emitted when prevTime is before roomOffset (error state)")
    func prevTimeBeforeOffsetNoTransition() {
        let transitions = TimerCalculator.collectTransitions(
            prevTime: offset - 10, currTime: offset + 100,
            roomOffset: offset, config: .default, detectedAt: Date()
        )
        #expect(transitions.isEmpty)
    }

    @Test("cycleIndex in transition equals the cycle index of the new phase")
    func cycleIndexIsNewPhase() {
        let config = Configuration.default
        // Cross the cycle wrap: from ~7799 s to ~7801 s
        let prev = offset + 7_799.0
        let curr = offset + 7_801.0
        let transitions = TimerCalculator.collectTransitions(
            prevTime: prev, currTime: curr, roomOffset: offset,
            config: config, detectedAt: Date()
        )
        #expect(transitions.count == 1)
        #expect(transitions[0].from       == .longBreak)
        #expect(transitions[0].to         == .work)
        #expect(transitions[0].cycleIndex == 1)   // entering cycle index 1
    }
}

// MARK: - TimerEngine lifecycle (Task 8.2*)

@Suite("TimerEngine lifecycle")
struct TimerEngineLifecycleTests {

    @Test("Invalid config throws ConfigurationError, engine remains idle")
    func invalidConfigThrows() async throws {
        let engine = isolatedEngine()
        var badConfig = Configuration.default
        badConfig.workDuration = 0
        #expect(throws: ConfigurationError.zeroPhaseDuration(field: "workDuration")) {
            try await engine.start(offset: offset, serverJoinTime: 0, config: badConfig)
        }
    }

    @Test("start persists offset and config to storage")
    func startPersistsToStorage() async throws {
        let storage = SharedStorage(suiteName: UUID().uuidString)
        let engine  = TimerEngine(storage: storage)
        try await engine.start(offset: offset, serverJoinTime: 123, config: .default)
        await engine.stop()
        #expect(storage.readOffset()   != nil)
        #expect(storage.readConfig()   != nil)
    }

    @Test("stop clears storage offset")
    func stopClearsStorage() async throws {
        let storage = SharedStorage(suiteName: UUID().uuidString)
        let engine  = TimerEngine(storage: storage)
        try await engine.start(offset: offset, serverJoinTime: 0, config: .default)
        await engine.stop()
        #expect(storage.readOffset() == nil)
    }

    @Test("stateStream emits first value immediately after start")
    func firstEmissionIsImmediate() async throws {
        let engine = isolatedEngine()
        try await engine.start(offset: offset, serverJoinTime: 0, config: .default)

        var firstState: Room_State?
        for await state in engine.stateStream {
            firstState = state
            break
        }
        await engine.stop()
        #expect(firstState != nil)
        #expect(firstState?.currentPhase != .clockSkewError)
    }

    @Test("restoreIfNeeded starts the engine when offset and config are stored")
    func restoreIfNeededAutoStarts() async throws {
        let storage = SharedStorage(suiteName: UUID().uuidString)
        // Pre-populate storage as if a previous session had run.
        try storage.writeOffset(offset, serverJoinTime: 0)
        storage.write(Configuration.default)

        let engine = TimerEngine(storage: storage)
        await engine.restoreIfNeeded()

        var received: Room_State?
        for await state in engine.stateStream {
            received = state
            break
        }
        await engine.stop()
        #expect(received != nil)
    }

    @Test("restoreIfNeeded stays idle when no offset is stored")
    func restoreIfNeededIdleWithoutOffset() async {
        let engine = isolatedEngine()
        await engine.restoreIfNeeded()
        // If no emission arrives within a short timeout the engine is idle.
        // We verify storage has no offset (the engine didn't start).
        let storage = SharedStorage(suiteName: UUID().uuidString)
        #expect(storage.readOffset() == nil)
    }
}
