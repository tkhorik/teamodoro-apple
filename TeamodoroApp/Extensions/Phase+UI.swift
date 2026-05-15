import SwiftUI
import SynchronizedTimerCore

extension Phase {
    /// Short label shown in the ring centre.
    var displayLabel: String {
        switch self {
        case .work:           return "FOCUS"
        case .shortBreak:     return "BREAK"
        case .longBreak:      return "REST"
        case .clockSkewError: return "SYNC ERR"
        }
    }

    /// Vibrant phase colour used for the countdown number and ring arc.
    var ringColor: Color {
        switch self {
        case .work:                    return .workColor
        case .shortBreak, .longBreak:  return .breakColor
        case .clockSkewError:          return .gray
        }
    }

    /// Muted variant used for the small phase label.
    var ringColorMuted: Color {
        switch self {
        case .work:                    return .workColorMuted
        case .shortBreak, .longBreak:  return .breakColorMuted
        case .clockSkewError:          return .gray.opacity(0.6)
        }
    }
}
