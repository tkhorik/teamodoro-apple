/// The Pomodoro phase a room is currently in.
public enum Phase: String, Codable, Sendable, Equatable, CaseIterable {
    case work
    case shortBreak
    case longBreak
    /// Returned when the device clock is behind the room offset (negative elapsed time).
    case clockSkewError
}
