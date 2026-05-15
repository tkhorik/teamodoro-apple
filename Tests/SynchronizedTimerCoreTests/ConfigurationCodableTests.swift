import Testing
import Foundation
@testable import SynchronizedTimerCore

@Suite("Configuration Codable")
struct ConfigurationCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Encode / decode helpers

    private func roundTrip(_ config: Configuration) throws -> Configuration {
        let data = try encoder.encode(config)
        return try decoder.decode(Configuration.self, from: data)
    }

    private func decode(_ json: String) throws -> Configuration {
        let data = Data(json.utf8)
        return try decoder.decode(Configuration.self, from: data)
    }

    // MARK: - Round-trip (Task 4.1 + Property 7)

    @Test("Default config survives encode → decode unchanged")
    func defaultRoundTrip() throws {
        let decoded = try roundTrip(.default)
        #expect(decoded == .default)
    }

    @Test("All four fields are preserved after encode → decode")
    func allFieldsPreserved() throws {
        let config = Configuration(
            workDuration: 1_200,
            shortBreakDuration: 180,
            longBreakDuration: 600,
            workPhasesBeforeLongBreak: 3
        )
        let decoded = try roundTrip(config)
        #expect(decoded.workDuration             == config.workDuration)
        #expect(decoded.shortBreakDuration       == config.shortBreakDuration)
        #expect(decoded.longBreakDuration        == config.longBreakDuration)
        #expect(decoded.workPhasesBeforeLongBreak == config.workPhasesBeforeLongBreak)
    }

    @Test("cycleDuration is NOT encoded (computed property)")
    func cycleDurationNotEncoded() throws {
        let data   = try encoder.encode(Configuration.default)
        let json   = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["cycleDuration"] == nil)
        #expect(json.count == 4)
    }

    // Property 7: Configuration Serialization Round-Trip (Task 4.2*)
    @Test("Property 7: 200 random valid configs survive encode → decode unchanged")
    func property7RoundTrip() throws {
        var rng = SeededRNG(seed: 20)
        for _ in 0 ..< 200 {
            let config  = Configuration.randomValid(using: &rng)
            let decoded = try roundTrip(config)
            #expect(decoded == config)
        }
    }

    // MARK: - Unknown fields ignored (Task 4.1)

    @Test("Unknown JSON fields are silently ignored")
    func unknownFieldsIgnored() throws {
        let json = """
        {
            "workDuration": 1500,
            "shortBreakDuration": 300,
            "longBreakDuration": 900,
            "workPhasesBeforeLongBreak": 4,
            "unknownFutureField": "some_value",
            "anotherField": 42
        }
        """
        let config = try decode(json)
        #expect(config == .default)
    }

    // MARK: - Missing fields rejected (Task 4.1, Property 8)

    @Test("Missing workDuration throws DecodingError")
    func missingWorkDuration() {
        let json = """
        {"shortBreakDuration": 300, "longBreakDuration": 900, "workPhasesBeforeLongBreak": 4}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("Missing shortBreakDuration throws DecodingError")
    func missingShortBreakDuration() {
        let json = """
        {"workDuration": 1500, "longBreakDuration": 900, "workPhasesBeforeLongBreak": 4}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("Missing longBreakDuration throws DecodingError")
    func missingLongBreakDuration() {
        let json = """
        {"workDuration": 1500, "shortBreakDuration": 300, "workPhasesBeforeLongBreak": 4}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("Missing workPhasesBeforeLongBreak throws DecodingError")
    func missingWorkPhaseCount() {
        let json = """
        {"workDuration": 1500, "shortBreakDuration": 300, "longBreakDuration": 900}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    // MARK: - Out-of-range values rejected via validation (Property 8)

    @Test("workPhasesBeforeLongBreak: 0 in JSON is rejected")
    func zeroWorkPhaseCount() {
        let json = """
        {"workDuration": 1500, "shortBreakDuration": 300, "longBreakDuration": 900, "workPhasesBeforeLongBreak": 0}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("workPhasesBeforeLongBreak: 11 in JSON is rejected")
    func elevenWorkPhaseCount() {
        let json = """
        {"workDuration": 1500, "shortBreakDuration": 300, "longBreakDuration": 900, "workPhasesBeforeLongBreak": 11}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("workDuration: 0 in JSON is rejected")
    func zeroWorkDuration() {
        let json = """
        {"workDuration": 0, "shortBreakDuration": 300, "longBreakDuration": 900, "workPhasesBeforeLongBreak": 4}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("Negative longBreakDuration in JSON is rejected")
    func negativeLongBreakDuration() {
        let json = """
        {"workDuration": 1500, "shortBreakDuration": 300, "longBreakDuration": -1, "workPhasesBeforeLongBreak": 4}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    // Property 8: Invalid JSON Configuration Rejected (Task 4.3*)
    @Test("Property 8: injecting zero duration into JSON always throws")
    func property8InvalidAlwaysThrows() throws {
        var rng = SeededRNG(seed: 21)
        for _ in 0 ..< 100 {
            var config = Configuration.randomValid(using: &rng)
            switch Int.random(in: 0 ..< 3, using: &rng) {
            case 0: config.workDuration       = 0
            case 1: config.shortBreakDuration = 0
            default: config.longBreakDuration = 0
            }
            // Encode manually (bypassing our custom init) then decode
            let dict: [String: Any] = [
                "workDuration":              config.workDuration,
                "shortBreakDuration":        config.shortBreakDuration,
                "longBreakDuration":         config.longBreakDuration,
                "workPhasesBeforeLongBreak": config.workPhasesBeforeLongBreak,
            ]
            let data = try JSONSerialization.data(withJSONObject: dict)
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(Configuration.self, from: data)
            }
        }
    }
}
