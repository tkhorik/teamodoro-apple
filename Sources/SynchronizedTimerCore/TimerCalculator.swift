import Foundation

/// Pure, stateless calculation layer for the synchronized timer.
///
/// All functions are deterministic: identical inputs always produce identical outputs.
/// There is no I/O, no async work, and no stored state — the type is an `enum` to
/// prevent instantiation. Every function is safe to call from any actor context.
public enum TimerCalculator {

    // MARK: - Phase Sequence

    /// Returns the ordered list of `(phase, cumulativeBoundary)` pairs for one full cycle.
    ///
    /// The interleaving pattern for `n = workPhasesBeforeLongBreak` is:
    /// ```
    /// W₁  SB₁  W₂  SB₂  …  W_(n-1)  SB_(n-1)  W_n  LB
    /// ```
    /// Each `boundary` value is cumulative from the start of the cycle, so the last
    /// element's `boundary` equals `config.cycleDuration`.
    ///
    /// - Parameter config: The room's cycle configuration. Must be valid (non-zero durations,
    ///   `workPhasesBeforeLongBreak` in [1, 10]); behaviour is undefined for invalid configs.
    public static func phaseSequence(
        for config: Configuration
    ) -> [(phase: Phase, boundary: TimeInterval)] {
        let n = config.workPhasesBeforeLongBreak
        var sequence: [(phase: Phase, boundary: TimeInterval)] = []
        sequence.reserveCapacity(n * 2)   // n work + (n-1) short breaks + 1 long break ≤ 2n

        var cumulative: TimeInterval = 0
        for i in 0 ..< n {
            cumulative += config.workDuration
            sequence.append((phase: .work, boundary: cumulative))
            if i < n - 1 {
                cumulative += config.shortBreakDuration
                sequence.append((phase: .shortBreak, boundary: cumulative))
            }
        }
        cumulative += config.longBreakDuration
        sequence.append((phase: .longBreak, boundary: cumulative))
        return sequence
    }

    // MARK: - Validation

    /// Validates a `Configuration`, returning the first error found or `nil` if valid.
    ///
    /// Checks (in order):
    /// 1. Each duration field — zero → `.zeroPhaseDuration`, negative → `.negativePhaseDuration`
    /// 2. `workPhasesBeforeLongBreak` outside [1, 10] → `.workPhaseCountOutOfRange`
    public static func validate(_ config: Configuration) -> ConfigurationError? {
        let durationFields: [(TimeInterval, String)] = [
            (config.workDuration,       "workDuration"),
            (config.shortBreakDuration, "shortBreakDuration"),
            (config.longBreakDuration,  "longBreakDuration"),
        ]
        for (duration, field) in durationFields {
            if duration == 0 { return .zeroPhaseDuration(field: field) }
            if duration  < 0 { return .negativePhaseDuration(field: field) }
        }
        let n = config.workPhasesBeforeLongBreak
        if n < 1 || n > 10 {
            return .workPhaseCountOutOfRange(value: n)
        }
        return nil
    }

    // MARK: - State Computation

    /// Computes the `Room_State` for a room at the given wall-clock time.
    ///
    /// - Parameters:
    ///   - roomOffset: Unix timestamp (seconds since 1970) at which the room's cycle epoch began.
    ///   - config: The room's cycle configuration. Must pass `validate(_:)`.
    ///   - currentTime: The current wall-clock time as a Unix timestamp.
    /// - Returns: The deterministically computed `Room_State`.
    ///   `clockSkewWarning` is always `false`; `TimerEngine` sets it after its skew check.
    public static func computeState(
        offset roomOffset: TimeInterval,
        config: Configuration,
        at currentTime: TimeInterval
    ) -> Room_State {
        let elapsed = currentTime - roomOffset

        // Negative elapsed → device clock is behind the room offset.
        guard elapsed >= 0 else {
            return Room_State(
                currentPhase: .clockSkewError,
                remainingSeconds: 0,
                cycleIndex: -1,
                clockSkewWarning: false
            )
        }

        let cycleDuration  = config.cycleDuration
        let cycleIndex     = Int(elapsed / cycleDuration)
        let cyclePosition  = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        let sequence = phaseSequence(for: config)
        for (phase, boundary) in sequence {
            if cyclePosition < boundary {
                // remainingSeconds: ceil of fractional seconds remaining, minimum 1.
                let remaining = max(1, Int(ceil(boundary - cyclePosition)))
                return Room_State(
                    currentPhase: phase,
                    remainingSeconds: remaining,
                    cycleIndex: cycleIndex,
                    clockSkewWarning: false
                )
            }
        }

        // Unreachable for valid configs: cyclePosition is always < cycleDuration,
        // which equals the last boundary. Guard here for compiler exhaustiveness.
        return Room_State(
            currentPhase: .work,
            remainingSeconds: 1,
            cycleIndex: cycleIndex,
            clockSkewWarning: false
        )
    }
}
