import Foundation

extension TimerCalculator {

    // MARK: - Phase transition collection

    /// Collects all phase transitions that occurred between two consecutive tick times.
    ///
    /// Rules:
    /// - Returns `[]` for backward clock adjustments (`currTime ≤ prevTime`).
    /// - Returns `[]` when `prevTime < roomOffset` (engine was in error state).
    /// - Emits one `PhaseTransition` per boundary crossed, in chronological order.
    ///   Forward clock jumps crossing multiple boundaries produce multiple events.
    ///
    /// This is a pure function so it can be unit-tested without the actor.
    public static func collectTransitions(
        prevTime: TimeInterval,
        currTime: TimeInterval,
        roomOffset: TimeInterval,
        config: Configuration,
        detectedAt: Date
    ) -> [PhaseTransition] {
        guard currTime > prevTime else { return [] }

        let prevElapsed = prevTime - roomOffset
        guard prevElapsed >= 0 else { return [] }

        let currElapsed    = currTime - roomOffset
        let cycleDuration  = config.cycleDuration
        let sequence       = phaseSequence(for: config)

        let prevCycleIdx   = Int(prevElapsed / cycleDuration)
        let currCycleIdx   = Int(currElapsed  / cycleDuration)

        var transitions: [PhaseTransition] = []

        // Walk every cycle that overlaps [prevElapsed, currElapsed].
        for cycleIdx in prevCycleIdx ... currCycleIdx {
            let cycleStart = cycleDuration * Double(cycleIdx)

            for (i, (_, boundary)) in sequence.enumerated() {
                let absoluteBoundary = cycleStart + boundary

                // Boundary must be strictly after prevElapsed and at-or-before currElapsed.
                guard absoluteBoundary > prevElapsed,
                      absoluteBoundary <= currElapsed else { continue }

                let fromPhase = sequence[i].phase
                let toPhase: Phase = i + 1 < sequence.count
                    ? sequence[i + 1].phase
                    : .work   // cycle wrap: long break → work

                // cycleIndex of the *new* phase being entered.
                let newCycleIdx = Int(absoluteBoundary / cycleDuration)

                transitions.append(PhaseTransition(
                    from: fromPhase,
                    to: toPhase,
                    cycleIndex: newCycleIdx,
                    timestamp: detectedAt
                ))
            }
        }

        // Already chronological (we iterate cycleIdx and boundary in order).
        return transitions
    }

    // MARK: - Clock skew

    /// Returns `true` when the device clock appears to be more than 5 s off the expected value.
    ///
    /// Formula: `|currentTime − (roomOffset + (nowAtJoin − serverJoinTime))| > 5.0`
    ///
    /// The boundary value 5.0 returns `false` (strictly greater-than).
    public static func computeSkewWarning(
        currentTime:    TimeInterval,
        roomOffset:     TimeInterval,
        nowAtJoin:      TimeInterval,
        serverJoinTime: TimeInterval
    ) -> Bool {
        let expected = roomOffset + (nowAtJoin - serverJoinTime)
        return abs(currentTime - expected) > 5.0
    }
}
