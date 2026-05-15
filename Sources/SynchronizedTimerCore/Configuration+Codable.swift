import Foundation

extension Configuration {
    // Explicit CodingKeys limits decoding to exactly these four fields;
    // unknown JSON keys are silently ignored (the default container behaviour).
    private enum CodingKeys: String, CodingKey {
        case workDuration
        case shortBreakDuration
        case longBreakDuration
        case workPhasesBeforeLongBreak
    }

    /// Decodes a `Configuration` from JSON and validates it before returning.
    ///
    /// Throws a `DecodingError` for:
    /// - missing required fields
    /// - type mismatches
    /// - values that fail `TimerCalculator.validate(_:)` (zero/negative durations,
    ///   `workPhasesBeforeLongBreak` outside [1, 10])
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let workDuration              = try c.decode(TimeInterval.self, forKey: .workDuration)
        let shortBreakDuration        = try c.decode(TimeInterval.self, forKey: .shortBreakDuration)
        let longBreakDuration         = try c.decode(TimeInterval.self, forKey: .longBreakDuration)
        let workPhasesBeforeLongBreak = try c.decode(Int.self,          forKey: .workPhasesBeforeLongBreak)

        self.init(
            workDuration: workDuration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            workPhasesBeforeLongBreak: workPhasesBeforeLongBreak
        )

        // Post-decode validation: surface ConfigurationError as DecodingError.
        if let error = TimerCalculator.validate(self) {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid Configuration: \(error)"
                )
            )
        }
    }

    /// Encodes only the four stored fields; `cycleDuration` is computed and excluded.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(workDuration,              forKey: .workDuration)
        try c.encode(shortBreakDuration,        forKey: .shortBreakDuration)
        try c.encode(longBreakDuration,         forKey: .longBreakDuration)
        try c.encode(workPhasesBeforeLongBreak, forKey: .workPhasesBeforeLongBreak)
    }
}
