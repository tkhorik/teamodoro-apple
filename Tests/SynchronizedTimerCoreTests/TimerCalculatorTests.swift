import Testing
@testable import SynchronizedTimerCore

// MARK: - Minimal seeded RNG (no external dependency)

/// A fast, deterministic PRNG (splitmix64) used to drive property tests.
/// Using a seeded generator keeps test runs reproducible across machines.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Generators

extension Configuration {
    /// Returns a random *valid* Configuration using the given RNG.
    static func randomValid(using rng: inout SeededRNG) -> Configuration {
        Configuration(
            workDuration:             Double.random(in: 1 ... 7_200, using: &rng),
            shortBreakDuration:       Double.random(in: 1 ... 7_200, using: &rng),
            longBreakDuration:        Double.random(in: 1 ... 7_200, using: &rng),
            workPhasesBeforeLongBreak: Int.random(in: 1 ... 10,      using: &rng)
        )
    }
}

// MARK: - TimerCalculator.phaseSequence (Task 2.1)

@Suite("TimerCalculator.phaseSequence")
struct PhaseSequenceTests {

    @Test("Default config produces 8-phase sequence with correct boundaries")
    func defaultConfigSequence() {
        let seq = TimerCalculator.phaseSequence(for: .default)
        let expectedPhases: [Phase]          = [.work, .shortBreak, .work, .shortBreak, .work, .shortBreak, .work, .longBreak]
        let expectedBoundaries: [TimeInterval] = [1_500, 1_800, 3_300, 3_600, 5_100, 5_400, 6_900, 7_800]

        #expect(seq.count == 8)
        for (i, (phase, boundary)) in seq.enumerated() {
            #expect(phase == expectedPhases[i],            "phase[\(i)]")
            #expect(abs(boundary - expectedBoundaries[i]) < 0.001, "boundary[\(i)]")
        }
    }

    @Test("n=1 produces two-element sequence: work then long break")
    func singleWorkPhase() {
        let config = Configuration(workDuration: 1_500, shortBreakDuration: 300, longBreakDuration: 900, workPhasesBeforeLongBreak: 1)
        let seq = TimerCalculator.phaseSequence(for: config)
        #expect(seq.count == 2)
        #expect(seq[0].phase == .work)
        #expect(seq[1].phase == .longBreak)
        #expect(abs(seq[0].boundary - 1_500) < 0.001)
        #expect(abs(seq[1].boundary - 2_400) < 0.001)
    }

    @Test("Last boundary equals cycleDuration for any valid config")
    func lastBoundaryEqualsCycleDuration() {
        var rng = SeededRNG(seed: 1)
        for _ in 0 ..< 200 {
            let config = Configuration.randomValid(using: &rng)
            let seq    = TimerCalculator.phaseSequence(for: config)
            #expect(abs(seq.last!.boundary - config.cycleDuration) < 0.001)
        }
    }

    @Test("Boundaries are strictly increasing")
    func boundariesStrictlyIncreasing() {
        var rng = SeededRNG(seed: 2)
        for _ in 0 ..< 200 {
            let config = Configuration.randomValid(using: &rng)
            let seq    = TimerCalculator.phaseSequence(for: config)
            for i in 1 ..< seq.count {
                #expect(seq[i].boundary > seq[i - 1].boundary)
            }
        }
    }

    @Test("Sequence length equals 2n − 1 + 1 = 2n phases (n work + n−1 short + 1 long)")
    func sequenceLengthFormula() {
        var rng = SeededRNG(seed: 3)
        for _ in 0 ..< 200 {
            let config = Configuration.randomValid(using: &rng)
            let n      = config.workPhasesBeforeLongBreak
            let seq    = TimerCalculator.phaseSequence(for: config)
            // n work + (n-1) short breaks + 1 long break = 2n
            #expect(seq.count == 2 * n)
        }
    }

    // Property 3: Phase Boundary Invariant (Task 2.2*)
    @Test("Property 3: state ε before boundary is in current phase; at boundary enters next phase")
    func phaseBoundaryInvariant() {
        let offset: TimeInterval = 1_700_000_000
        let epsilon: TimeInterval = 0.001
        var rng = SeededRNG(seed: 4)
        for _ in 0 ..< 100 {
            let config = Configuration.randomValid(using: &rng)
            let seq    = TimerCalculator.phaseSequence(for: config)
            for (idx, (phase, boundary)) in seq.enumerated() {
                // Just before the boundary → still in `phase`
                let before = TimerCalculator.computeState(
                    offset: offset, config: config, at: offset + boundary - epsilon
                )
                #expect(before.currentPhase == phase, "before boundary[\(idx)]: expected \(phase)")

                // At the boundary → first position of the next phase
                if idx < seq.count - 1 {
                    let at       = TimerCalculator.computeState(
                        offset: offset, config: config, at: offset + boundary
                    )
                    let nextPhase = seq[idx + 1].phase
                    #expect(at.currentPhase == nextPhase, "at boundary[\(idx)]: expected \(nextPhase)")
                }
            }
        }
    }
}

// MARK: - TimerCalculator.validate (Task 2.3)

@Suite("TimerCalculator.validate")
struct ValidateTests {

    @Test("Valid default config returns nil")
    func validDefaultReturnsNil() {
        #expect(TimerCalculator.validate(.default) == nil)
    }

    @Test("Zero workDuration → zeroPhaseDuration")
    func zeroWork() {
        var c = Configuration.default; c.workDuration = 0
        #expect(TimerCalculator.validate(c) == .zeroPhaseDuration(field: "workDuration"))
    }

    @Test("Zero shortBreakDuration → zeroPhaseDuration")
    func zeroShortBreak() {
        var c = Configuration.default; c.shortBreakDuration = 0
        #expect(TimerCalculator.validate(c) == .zeroPhaseDuration(field: "shortBreakDuration"))
    }

    @Test("Zero longBreakDuration → zeroPhaseDuration")
    func zeroLongBreak() {
        var c = Configuration.default; c.longBreakDuration = 0
        #expect(TimerCalculator.validate(c) == .zeroPhaseDuration(field: "longBreakDuration"))
    }

    @Test("Negative workDuration → negativePhaseDuration")
    func negativeWork() {
        var c = Configuration.default; c.workDuration = -1
        #expect(TimerCalculator.validate(c) == .negativePhaseDuration(field: "workDuration"))
    }

    @Test("Negative shortBreakDuration → negativePhaseDuration")
    func negativeShortBreak() {
        var c = Configuration.default; c.shortBreakDuration = -300
        #expect(TimerCalculator.validate(c) == .negativePhaseDuration(field: "shortBreakDuration"))
    }

    @Test("Negative longBreakDuration → negativePhaseDuration")
    func negativeLongBreak() {
        var c = Configuration.default; c.longBreakDuration = -1
        #expect(TimerCalculator.validate(c) == .negativePhaseDuration(field: "longBreakDuration"))
    }

    @Test("workPhasesBeforeLongBreak=0 → workPhaseCountOutOfRange")
    func workCountZero() {
        var c = Configuration.default; c.workPhasesBeforeLongBreak = 0
        #expect(TimerCalculator.validate(c) == .workPhaseCountOutOfRange(value: 0))
    }

    @Test("workPhasesBeforeLongBreak=11 → workPhaseCountOutOfRange")
    func workCountEleven() {
        var c = Configuration.default; c.workPhasesBeforeLongBreak = 11
        #expect(TimerCalculator.validate(c) == .workPhaseCountOutOfRange(value: 11))
    }

    @Test("Boundary values 1 and 10 are valid")
    func workCountBoundariesValid() {
        var c = Configuration.default
        c.workPhasesBeforeLongBreak = 1;  #expect(TimerCalculator.validate(c) == nil)
        c.workPhasesBeforeLongBreak = 10; #expect(TimerCalculator.validate(c) == nil)
    }

    // Property 5: Configuration Validation (Task 2.4*)
    @Test("Property 5: 200 random valid configs all return nil")
    func property5ValidConfigsReturnNil() {
        var rng = SeededRNG(seed: 5)
        for _ in 0 ..< 200 {
            let config = Configuration.randomValid(using: &rng)
            #expect(TimerCalculator.validate(config) == nil)
        }
    }

    @Test("Property 5: injecting a zero duration always returns non-nil")
    func property5InvalidConfigsReturnError() {
        var rng = SeededRNG(seed: 6)
        for _ in 0 ..< 200 {
            var config = Configuration.randomValid(using: &rng)
            // Randomly zero out one of the three duration fields
            switch Int.random(in: 0 ..< 3, using: &rng) {
            case 0: config.workDuration       = 0
            case 1: config.shortBreakDuration = 0
            default: config.longBreakDuration = 0
            }
            #expect(TimerCalculator.validate(config) != nil)
        }
    }

    @Test("Property 5: out-of-range work count always returns non-nil")
    func property5OutOfRangeWorkCount() {
        var rng = SeededRNG(seed: 7)
        for _ in 0 ..< 100 {
            var config = Configuration.randomValid(using: &rng)
            config.workPhasesBeforeLongBreak = Bool.random(using: &rng) ? 0 : 11
            #expect(TimerCalculator.validate(config) != nil)
        }
    }
}

// MARK: - TimerCalculator.computeState (Task 2.5)

@Suite("TimerCalculator.computeState")
struct ComputeStateTests {

    /// A stable, arbitrary epoch used as roomOffset across all tests.
    let offset: TimeInterval = 1_700_000_000

    @Test("Negative elapsed → clockSkewError state")
    func negativeElapsedIsError() {
        let state = TimerCalculator.computeState(offset: offset, config: .default, at: offset - 1)
        #expect(state.currentPhase    == .clockSkewError)
        #expect(state.remainingSeconds == 0)
        #expect(state.cycleIndex       == -1)
        #expect(state.clockSkewWarning == false)
    }

    @Test("Elapsed = 0 → start of first work phase, 1500 s remaining")
    func atZeroElapsed() {
        let state = TimerCalculator.computeState(offset: offset, config: .default, at: offset)
        #expect(state.currentPhase    == .work)
        #expect(state.remainingSeconds == 1_500)
        #expect(state.cycleIndex       == 0)
        #expect(state.clockSkewWarning == false)
    }

    @Test("Elapsed = 750 → mid-work, 750 s remaining")
    func midFirstWorkPhase() {
        let state = TimerCalculator.computeState(offset: offset, config: .default, at: offset + 750)
        #expect(state.currentPhase    == .work)
        #expect(state.remainingSeconds == 750)
    }

    @Test("Elapsed = 1500 → start of first short break, 300 s remaining")
    func atFirstShortBreakStart() {
        let state = TimerCalculator.computeState(offset: offset, config: .default, at: offset + 1_500)
        #expect(state.currentPhase    == .shortBreak)
        #expect(state.remainingSeconds == 300)
    }

    @Test("Elapsed = 6900 → start of long break, 900 s remaining")
    func atLongBreakStart() {
        let state = TimerCalculator.computeState(offset: offset, config: .default, at: offset + 6_900)
        #expect(state.currentPhase    == .longBreak)
        #expect(state.remainingSeconds == 900)
    }

    @Test("Elapsed = cycleDuration → wraps into cycle 1, back to work")
    func cycleWrap() {
        let cd    = Configuration.default.cycleDuration  // 7800 s
        let state = TimerCalculator.computeState(offset: offset, config: .default, at: offset + cd)
        #expect(state.currentPhase == .work)
        #expect(state.cycleIndex   == 1)
    }

    @Test("cycleIndex increments correctly across 5 cycles")
    func cycleIndexIncrements() {
        let cd = Configuration.default.cycleDuration
        for i in 0 ..< 5 {
            let t     = offset + cd * Double(i) + 1.0
            let state = TimerCalculator.computeState(offset: offset, config: .default, at: t)
            #expect(state.cycleIndex == i, "cycle \(i)")
        }
    }

    @Test("remainingSeconds is always ≥ 1 for non-error states")
    func remainingSecondsAlwaysPositive() {
        var rng = SeededRNG(seed: 8)
        for _ in 0 ..< 300 {
            let config  = Configuration.randomValid(using: &rng)
            let elapsed = Double.random(in: 0 ... 1_000_000, using: &rng)
            let state   = TimerCalculator.computeState(offset: 0, config: config, at: elapsed)
            if state.currentPhase != .clockSkewError {
                #expect(state.remainingSeconds >= 1)
            }
        }
    }

    // Property 1: Deterministic State Computation (Task 2.6*)
    @Test("Property 1: identical inputs always produce identical Room_State")
    func property1Deterministic() {
        var rng = SeededRNG(seed: 9)
        for _ in 0 ..< 300 {
            let config = Configuration.randomValid(using: &rng)
            let t      = Double.random(in: 0 ... 500_000, using: &rng)
            let s1     = TimerCalculator.computeState(offset: offset, config: config, at: offset + t)
            let s2     = TimerCalculator.computeState(offset: offset, config: config, at: offset + t)
            #expect(s1 == s2)
        }
    }

    // Property 2: State Formula Invariants (Task 2.7*)
    @Test("Property 2: cycleIndex == Int(elapsed/cycleDuration); remainingSeconds in [1, maxPhase]")
    func property2FormulaInvariants() {
        var rng = SeededRNG(seed: 10)
        for _ in 0 ..< 300 {
            let config  = Configuration.randomValid(using: &rng)
            let elapsed = Double.random(in: 0 ... 1_000_000, using: &rng)
            let state   = TimerCalculator.computeState(offset: 0, config: config, at: elapsed)
            guard state.currentPhase != .clockSkewError else { continue }

            #expect(state.cycleIndex == Int(elapsed / config.cycleDuration))

            let maxPhase = max(config.workDuration, config.shortBreakDuration, config.longBreakDuration)
            // remainingSeconds is at most ceil(maxPhaseDuration), so ≤ Int(maxPhase) + 1
            #expect(Double(state.remainingSeconds) <= maxPhase + 1)
            #expect(state.remainingSeconds >= 1)
        }
    }

    // Property 4: Negative Elapsed Produces Error State (Task 2.8*)
    @Test("Property 4: any currentTime < roomOffset produces clockSkewError")
    func property4NegativeElapsedAlwaysError() {
        var rng = SeededRNG(seed: 11)
        for _ in 0 ..< 300 {
            let config  = Configuration.randomValid(using: &rng)
            let negTime = Double.random(in: -500_000 ... -0.001, using: &rng)
            let state   = TimerCalculator.computeState(offset: 0, config: config, at: negTime)
            #expect(state.currentPhase    == .clockSkewError, "phase")
            #expect(state.remainingSeconds == 0,              "remaining")
            #expect(state.cycleIndex       == -1,             "cycleIndex")
        }
    }
}
