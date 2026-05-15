/// Errors produced when a `Configuration` value fails validation.
public enum ConfigurationError: Error, Equatable, Sendable {
    /// A phase duration field is exactly zero.
    case zeroPhaseDuration(field: String)
    /// A phase duration field is negative.
    case negativePhaseDuration(field: String)
    /// `workPhasesBeforeLongBreak` is outside the allowed range [1, 10].
    case workPhaseCountOutOfRange(value: Int)
}

/// Errors produced by `SharedStorage`.
public enum StorageError: Error, Equatable, Sendable {
    /// The provided offset is NaN or ±Infinity and cannot be stored.
    case invalidOffset
}
