import Foundation

/// Immutable configuration for a Teamodoro room cycle.
public struct Configuration: Codable, Sendable, Equatable {
    /// Duration of a single work phase in seconds.
    public var workDuration: TimeInterval
    /// Duration of a short break in seconds.
    public var shortBreakDuration: TimeInterval
    /// Duration of the long break at the end of a cycle in seconds.
    public var longBreakDuration: TimeInterval
    /// Number of work phases before the long break. Must be in [1, 10].
    public var workPhasesBeforeLongBreak: Int

    /// Total duration of one full cycle in seconds.
    ///
    /// Formula: `workDuration × n + shortBreakDuration × (n − 1) + longBreakDuration`
    /// where `n = workPhasesBeforeLongBreak`.
    public var cycleDuration: TimeInterval {
        workDuration * Double(workPhasesBeforeLongBreak)
            + shortBreakDuration * Double(workPhasesBeforeLongBreak - 1)
            + longBreakDuration
    }

    /// Default Teamodoro cycle: 4 × 25 min work / 3 × 5 min short break / 15 min long break = 130 min.
    public static let `default` = Configuration(
        workDuration: 1_500,
        shortBreakDuration: 300,
        longBreakDuration: 900,
        workPhasesBeforeLongBreak: 4
    )

    public init(
        workDuration: TimeInterval,
        shortBreakDuration: TimeInterval,
        longBreakDuration: TimeInterval,
        workPhasesBeforeLongBreak: Int
    ) {
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.workPhasesBeforeLongBreak = workPhasesBeforeLongBreak
    }
}
