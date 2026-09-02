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

@Test func applyingWritesAndRestarts() throws {
    let store = try fixtureStore()
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, restarter: restarter)

    var target = try engine.read()
    target.apps = [DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )]
    try engine.apply(target)

    #expect(try engine.read().apps.count == 1)
    #expect(restarter.restarts == 1)
}

@Test func anUnreadableDomainForbidsWriting() throws {
    let store = InMemoryDockStore([DockKey.tilesize: "large"])
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, restarter: restarter)

    #expect(throws: DockReadError.self) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    #expect(store.value(forKey: DockKey.apps) == nil)
    #expect(restarter.restarts == 0)
}

@Test func aSyncFailureCancelsTheRestart() throws {
    let store = try NonSynchronizingStore(fixtureStore())
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, restarter: restarter)

    #expect(throws: DockWriteError.synchronizeFailed) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    #expect(restarter.restarts == 0)
}

@Test func aRestartErrorIsNotSwallowedButTheWriteIsDone() throws {
    let store = try fixtureStore()
    let restarter = FakeRestarter()
    restarter.errorToThrow = .terminateRefused
    let engine = DockEngine(store: store, restarter: restarter)

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
}

@Test func theRestartCounterCountsAttemptsNotSuccesses() throws {
    let restarter = FakeRestarter()
    restarter.errorToThrow = .terminateRefused
    let engine = try DockEngine(
        store: fixtureStore(),
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
    private let runningForChecks: Int
    private nonisolated(unsafe) var _asked = false
    private nonisolated(unsafe) var _checks = 0

    init(quits: Bool, runningForChecks: Int = 0) {
        self.quits = quits
        self.runningForChecks = runningForChecks
    }

    var wasAsked: Bool {
        lock.withLock { _asked }
    }

    var checks: Int {
        lock.withLock { _checks }
    }

    func terminate() -> Bool {
        lock.withLock { _asked = true }
        return quits
    }

    var isRunning: Bool {
        lock.withLock {
            _checks += 1
            return _checks <= runningForChecks
        }
    }
}

@Test func noDockRunningIsNotTreatedAsARestartFailure() throws {
    let restarter = DockRestarter(processes: { [] })
    #expect(throws: Never.self) { try restarter.restart() }
}

@Test func aRunningDockIsAskedToQuit() throws {
    let dock = FakeDockProcess(quits: true)
    try DockRestarter(processes: { [dock] }).restart()
    #expect(dock.wasAsked)
}

@Test func applyingAStateTheDockAlreadyHoldsWritesNothing() throws {
    let restarter = FakeRestarter()
    let engine = try DockEngine(
        store: fixtureStore(),
        restarter: restarter
    )

    #expect(try engine.applyIfNeeded(engine.read()) == false)
    #expect(restarter.restarts == 0)
}

@Test func applyingADifferentStateWritesAndRestarts() throws {
    let restarter = FakeRestarter()
    let engine = try DockEngine(
        store: fixtureStore(),
        restarter: restarter
    )

    var wanted = try engine.read()
    wanted.settings.autohide = !(wanted.settings.autohide ?? false)

    #expect(try engine.applyIfNeeded(wanted) == true)
    #expect(restarter.restarts == 1)
    #expect(try engine.read().settings.autohide == wanted.settings.autohide)
}

@Test func applyingASavedStateAgainPutsBackEverySettingTheAppCanChange() throws {
    let engine = try DockEngine(
        store: fixtureStore(),
        restarter: FakeRestarter()
    )
    let saved = try engine.read()

    var drifted = DockState(apps: [], settings: DockSettings())
    drifted.settings.tilesize = 99
    drifted.settings.orientation = .left
    try engine.apply(drifted)
    #expect(try engine.read() != saved)

    try engine.apply(saved)

    #expect(try engine.read() == saved)
}

@Test func aDockThatIgnoresTheQuitRequestIsARestartFailure() {
    let stubborn = FakeDockProcess(quits: true, runningForChecks: .max)
    let restarter = DockRestarter(
        processes: { [stubborn] },
        timeout: 0.05,
        pollInterval: 0.005
    )

    #expect(throws: DockRestartError.terminateRefused) { try restarter.restart() }
    #expect(stubborn.wasAsked)
}

@Test func aDockThatHasAlreadyQuitIsNotARestartFailure() {
    let gone = FakeDockProcess(quits: false)

    #expect(throws: Never.self) { try DockRestarter(processes: { [gone] }).restart() }
    #expect(gone.wasAsked)
}

@Test func aDockThatTakesAMomentToQuitIsWaitedForAndNoLonger() throws {
    let slow = FakeDockProcess(quits: true, runningForChecks: 3)
    let restarter = DockRestarter(
        processes: { [slow] },
        timeout: 2,
        pollInterval: 0.005
    )

    let started = DispatchTime.now().uptimeNanoseconds
    try restarter.restart()
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9

    #expect(slow.checks > 1)
    #expect(elapsed < 1)
}
