import Foundation
@testable import ShitsuraeCore
import Testing

private final class FakeRestarter: DockRestarting {
    private let lock = NSLock()
    private nonisolated(unsafe) var _restarts = 0
    private nonisolated(unsafe) var _errorToThrow: DockRestartError?

    var restarts: Int {
        lock.withLock { _restarts }
    }

    var errorToThrow: DockRestartError? {
        get { lock.withLock { _errorToThrow } }
        set { lock.withLock { _errorToThrow = newValue } }
    }

    func restart() throws {
        lock.withLock { _restarts += 1 }
        if let error = errorToThrow {
            throw error
        }
    }
}

private final class NonSynchronizingStore: DockPreferenceStore {
    private let inner: InMemoryDockStore

    init(_ inner: InMemoryDockStore) {
        self.inner = inner
    }

    func value(forKey key: String) -> Any? {
        inner.value(forKey: key)
    }

    func setValue(_ value: Any?, forKey key: String) {
        inner.setValue(value, forKey: key)
    }

    @discardableResult func synchronize() -> Bool {
        false
    }
}

private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-engine-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func applyingWritesBacksUpAndRestarts() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try fixtureStore()
    let backup = DockBackup(directory: dir)
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: backup, restarter: restarter)

    var target = try engine.read()
    target.apps = [DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )]
    try engine.apply(target)

    #expect(try engine.read().apps.count == 1)
    #expect(backup.exists == true)
    #expect(restarter.restarts == 1)
}

@Test func anUnreadableDomainForbidsWriting() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = InMemoryDockStore([DockKey.tilesize: "large"])
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: DockBackup(directory: dir), restarter: restarter)

    #expect(throws: DockReadError.self) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    #expect(store.value(forKey: DockKey.apps) == nil)
    #expect(restarter.restarts == 0)
    #expect(DockBackup(directory: dir).exists == false)
}

@Test func reapplyingDoesNotMakeASecondBackup() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let engine = try DockEngine(
        store: fixtureStore(),
        backup: DockBackup(directory: dir),
        restarter: FakeRestarter()
    )
    let state = try engine.read()
    try engine.apply(state)
    let first = try Data(contentsOf: DockBackup(directory: dir).backupURL)
    try engine.apply(state)
    #expect(try Data(contentsOf: DockBackup(directory: dir).backupURL) == first)
}

@Test func aSyncFailureCancelsTheRestart() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try NonSynchronizingStore(fixtureStore())
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: DockBackup(directory: dir), restarter: restarter)

    #expect(throws: DockWriteError.synchronizeFailed) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    #expect(restarter.restarts == 0)
}

@Test func aRestartErrorIsNotSwallowedButTheWriteAndBackupAreDone() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try fixtureStore()
    let backup = DockBackup(directory: dir)
    let restarter = FakeRestarter()
    restarter.errorToThrow = .terminateRefused
    let engine = DockEngine(store: store, backup: backup, restarter: restarter)

    var target = try engine.read()
    target.apps = [DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )]

    #expect(throws: DockRestartError.self) {
        try engine.apply(target)
    }

    #expect(try engine.read().apps.count == 1)
    #expect(backup.exists == true)
}

@Test func theRestartCounterCountsAttemptsNotSuccesses() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let restarter = FakeRestarter()
    restarter.errorToThrow = .terminateRefused
    let engine = try DockEngine(
        store: fixtureStore(),
        backup: DockBackup(directory: dir),
        restarter: restarter
    )

    #expect(throws: DockRestartError.terminateRefused) {
        try engine.apply(engine.read())
    }
    #expect(restarter.restarts == 1)
}

private final class FakeDockProcess: DockProcess, @unchecked Sendable {
    private let lock = NSLock()
    private let quits: Bool
    private nonisolated(unsafe) var _asked = false

    init(quits: Bool) {
        self.quits = quits
    }

    var wasAsked: Bool {
        lock.withLock { _asked }
    }

    func terminate() -> Bool {
        lock.withLock { _asked = true }
        return quits
    }
}

@Test func noDockRunningIsNotTreatedAsARestartFailure() throws {
    let restarter = DockRestarter(processes: { [] })
    #expect(throws: Never.self) { try restarter.restart() }
}

@Test func aDockThatRefusesToQuitIsARestartFailure() {
    let stubborn = FakeDockProcess(quits: false)
    let restarter = DockRestarter(processes: { [stubborn] })

    #expect(throws: DockRestartError.terminateRefused) { try restarter.restart() }
    #expect(stubborn.wasAsked)
}

@Test func aRunningDockIsAskedToQuit() throws {
    let dock = FakeDockProcess(quits: true)
    try DockRestarter(processes: { [dock] }).restart()
    #expect(dock.wasAsked)
}
