import Foundation

/// Typed App Group `UserDefaults` accessors shared between the main app, widgets,
/// and Live Activities.
///
/// `UserDefaults` is documented as thread-safe for reads and writes; `@unchecked Sendable`
/// reflects that guarantee without requiring actor isolation on every call site.
public struct SharedStorage: @unchecked Sendable {

    // MARK: - Keys

    private enum Key {
        static let roomOffset             = "timer.roomOffset"
        static let serverJoinTime         = "timer.serverJoinTime"
        static let latestState            = "timer.latestState"
        static let config                 = "timer.config"
    }

    // MARK: - Storage backend

    private let defaults: UserDefaults

    /// The default shared instance uses the production App Group suite.
    public static let shared = SharedStorage()

    /// Designated initialiser.
    ///
    /// - Parameter suiteName: Defaults to `"group.com.teamodoro.shared"`. Pass a unique
    ///   UUID string in tests to get an isolated, throwaway suite.
    public init(suiteName: String = "group.com.teamodoro.shared") {
        // Fall back to `.standard` only in unit-test environments where the App Group
        // entitlement is not configured; production builds should always resolve the suite.
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Room Offset

    /// Persists the room offset and server join time.
    ///
    /// - Throws: `StorageError.invalidOffset` when `offset` is NaN or ±Infinity.
    ///   Storage is left unchanged on error.
    public func writeOffset(_ offset: TimeInterval, serverJoinTime: TimeInterval) throws {
        guard offset.isFinite else { throw StorageError.invalidOffset }
        defaults.set(offset,         forKey: Key.roomOffset)
        defaults.set(serverJoinTime, forKey: Key.serverJoinTime)
    }

    /// Returns the stored room offset, or `nil` if none has been written.
    public func readOffset() -> TimeInterval? {
        guard defaults.object(forKey: Key.roomOffset) != nil else { return nil }
        return defaults.double(forKey: Key.roomOffset)
    }

    /// Returns the stored server join time, or `nil` if none has been written.
    public func readServerJoinTime() -> TimeInterval? {
        guard defaults.object(forKey: Key.serverJoinTime) != nil else { return nil }
        return defaults.double(forKey: Key.serverJoinTime)
    }

    /// Removes both `timer.roomOffset` and `timer.serverJoinTime` from storage.
    public func clearOffset() {
        defaults.removeObject(forKey: Key.roomOffset)
        defaults.removeObject(forKey: Key.serverJoinTime)
    }

    // MARK: - Room State

    /// JSON-encodes `state` and writes it to `timer.latestState`.
    public func write(_ state: Room_State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Key.latestState)
    }

    /// Decodes and returns the last persisted `Room_State`, or `nil` if none exists.
    public func readLatestState() -> Room_State? {
        guard let data = defaults.data(forKey: Key.latestState) else { return nil }
        return try? JSONDecoder().decode(Room_State.self, from: data)
    }

    // MARK: - Configuration

    /// JSON-encodes `config` and writes it to `timer.config`.
    public func write(_ config: Configuration) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Key.config)
    }

    /// Decodes and returns the last persisted `Configuration`, or `nil` if none exists.
    public func readConfig() -> Configuration? {
        guard let data = defaults.data(forKey: Key.config) else { return nil }
        return try? JSONDecoder().decode(Configuration.self, from: data)
    }
}
