/// A snapshot of the timer state for a room at a point in time.
public struct Room_State: Codable, Sendable, Equatable {
    /// The phase the room is currently in.
    public var currentPhase: Phase
    /// Seconds remaining in the current phase (always ≥ 1 for non-error states).
    public var remainingSeconds: Int
    /// Number of complete cycles elapsed since room creation (−1 for `.clockSkewError`).
    public var cycleIndex: Int
    /// `true` when the device clock appears to be more than 5 s off the expected value.
    ///
    /// This flag is set by `TimerEngine` after the skew calculation; `TimerCalculator` always
    /// returns `false` here.
    public var clockSkewWarning: Bool

    public init(
        currentPhase: Phase,
        remainingSeconds: Int,
        cycleIndex: Int,
        clockSkewWarning: Bool
    ) {
        self.currentPhase = currentPhase
        self.remainingSeconds = remainingSeconds
        self.cycleIndex = cycleIndex
        self.clockSkewWarning = clockSkewWarning
    }
}
