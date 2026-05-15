import Foundation

/// Emitted by `TimerEngine` when the timer crosses a phase boundary.
public struct PhaseTransition: Sendable, Equatable {
    /// The phase that just ended.
    public var from: Phase
    /// The phase that just began.
    public var to: Phase
    /// The cycle index at the moment of the transition.
    public var cycleIndex: Int
    /// The device wall-clock time at which the transition was detected.
    public var timestamp: Date

    public init(from: Phase, to: Phase, cycleIndex: Int, timestamp: Date) {
        self.from = from
        self.to = to
        self.cycleIndex = cycleIndex
        self.timestamp = timestamp
    }
}
