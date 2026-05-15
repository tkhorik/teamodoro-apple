import Testing
import Foundation
@testable import SynchronizedTimerCore

// Each test gets a fresh, isolated UserDefaults suite so tests can't pollute each other.
private func makeStorage() -> SharedStorage {
    let suite = UUID().uuidString
    let storage = SharedStorage(suiteName: suite)
    return storage
}

@Suite("SharedStorage — offset persistence")
struct SharedStorageOffsetTests {

    // MARK: - Basic round-trip

    @Test("Write then read returns the same offset (within 0.001 s)")
    func offsetRoundTrip() throws {
        let storage = makeStorage()
        let offset: TimeInterval = 1_700_000_000.5
        try storage.writeOffset(offset, serverJoinTime: 1_700_000_100)
        let readBack = try #require(storage.readOffset())
        #expect(abs(readBack - offset) < 0.001)
    }

    @Test("readOffset before any write returns nil")
    func readBeforeWriteIsNil() {
        let storage = makeStorage()
        #expect(storage.readOffset() == nil)
    }

    @Test("readServerJoinTime before any write returns nil")
    func readServerJoinTimeBeforeWriteIsNil() {
        let storage = makeStorage()
        #expect(storage.readServerJoinTime() == nil)
    }

    @Test("serverJoinTime is stored alongside offset")
    func serverJoinTimePersisted() throws {
        let storage = makeStorage()
        let joinTime: TimeInterval = 1_700_000_200.75
        try storage.writeOffset(1_700_000_000, serverJoinTime: joinTime)
        let readBack = try #require(storage.readServerJoinTime())
        #expect(abs(readBack - joinTime) < 0.001)
    }

    // MARK: - Invalid offsets (Task 5.1 + 5.3)

    @Test("NaN offset throws invalidOffset and leaves storage unchanged")
    func nanOffsetRejected() throws {
        let storage = makeStorage()
        try storage.writeOffset(1_700_000_000, serverJoinTime: 0)   // valid write first
        #expect(throws: StorageError.invalidOffset) {
            try storage.writeOffset(.nan, serverJoinTime: 0)
        }
        // Storage must still hold the previously valid offset
        #expect(storage.readOffset() != nil)
    }

    @Test("+Infinity offset throws invalidOffset")
    func positiveInfinityRejected() {
        let storage = makeStorage()
        #expect(throws: StorageError.invalidOffset) {
            try storage.writeOffset(.infinity, serverJoinTime: 0)
        }
        #expect(storage.readOffset() == nil)
    }

    @Test("-Infinity offset throws invalidOffset")
    func negativeInfinityRejected() {
        let storage = makeStorage()
        #expect(throws: StorageError.invalidOffset) {
            try storage.writeOffset(-.infinity, serverJoinTime: 0)
        }
        #expect(storage.readOffset() == nil)
    }

    // MARK: - clearOffset (Task 5.1 + 5.3)

    @Test("clearOffset removes both roomOffset and serverJoinTime")
    func clearOffsetRemovesBothKeys() throws {
        let storage = makeStorage()
        try storage.writeOffset(1_700_000_000, serverJoinTime: 1_700_000_100)
        storage.clearOffset()
        #expect(storage.readOffset()         == nil)
        #expect(storage.readServerJoinTime() == nil)
    }

    @Test("clearOffset on empty storage is a no-op")
    func clearOffsetOnEmpty() {
        let storage = makeStorage()
        storage.clearOffset()   // should not crash
        #expect(storage.readOffset() == nil)
    }

    // Property 6: Room_Offset Persistence Round-Trip (Task 5.2*)
    @Test("Property 6: 200 random finite offsets survive write → read within 0.001 s")
    func property6OffsetRoundTrip() throws {
        var rng = SeededRNG(seed: 30)
        for _ in 0 ..< 200 {
            let storage = makeStorage()
            let offset  = Double.random(in: -1_000_000_000 ... 2_000_000_000, using: &rng)
            let joinTime = Double.random(in: 0 ... 2_000_000_000, using: &rng)
            try storage.writeOffset(offset, serverJoinTime: joinTime)
            let readBack = try #require(storage.readOffset())
            #expect(abs(readBack - offset) < 0.001)
        }
    }
}

@Suite("SharedStorage — Room_State persistence")
struct SharedStorageStateTests {

    @Test("write then readLatestState returns equal value")
    func stateRoundTrip() {
        let storage = makeStorage()
        let state   = Room_State(currentPhase: .shortBreak, remainingSeconds: 245, cycleIndex: 2, clockSkewWarning: true)
        storage.write(state)
        let readBack = storage.readLatestState()
        #expect(readBack == state)
    }

    @Test("readLatestState before any write returns nil")
    func readStateBeforeWriteIsNil() {
        #expect(makeStorage().readLatestState() == nil)
    }

    @Test("Second write overwrites the first")
    func stateOverwritten() {
        let storage = makeStorage()
        storage.write(Room_State(currentPhase: .work,       remainingSeconds: 1_000, cycleIndex: 0, clockSkewWarning: false))
        storage.write(Room_State(currentPhase: .longBreak,  remainingSeconds: 42,    cycleIndex: 1, clockSkewWarning: true))
        let readBack = storage.readLatestState()
        #expect(readBack?.currentPhase    == .longBreak)
        #expect(readBack?.remainingSeconds == 42)
    }
}

@Suite("SharedStorage — Configuration persistence")
struct SharedStorageConfigTests {

    @Test("write then readConfig returns equal value")
    func configRoundTrip() {
        let storage = makeStorage()
        storage.write(.default)
        #expect(storage.readConfig() == .default)
    }

    @Test("readConfig before any write returns nil")
    func readConfigBeforeWriteIsNil() {
        #expect(makeStorage().readConfig() == nil)
    }

    @Test("Custom config survives write → read")
    func customConfigRoundTrip() {
        let storage = makeStorage()
        let config  = Configuration(workDuration: 1_200, shortBreakDuration: 180, longBreakDuration: 720, workPhasesBeforeLongBreak: 3)
        storage.write(config)
        #expect(storage.readConfig() == config)
    }
}
