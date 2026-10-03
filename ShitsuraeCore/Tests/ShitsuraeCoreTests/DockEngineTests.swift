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

    func restart() throws(DockRestartError) {
        lock.withLock { _restarts += 1 }
        if let error = errorToThrow {
            throw error
        }
    }

    func waitUntilRunning() {}
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

    #expect(throws: DockError.read(.wrongType(key: DockKey.tilesize, expected: "Number"))) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    #expect(store.value(forKey: DockKey.apps) == nil)
    #expect(restarter.restarts == 0)
}

@Test func aSyncFailureCancelsTheRestart() throws {
    let store = try NonSynchronizingStore(fixtureStore())
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, restarter: restarter)

    #expect(throws: DockError.write(.synchronizeFailed)) {
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

    #expect(throws: DockError.restart(.terminateRefused)) {
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

    #expect(throws: DockError.restart(.terminateRefused)) {
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

    #expect(try engine.applyIfNeeded(engine.read()) == .alreadyHeld)
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

    #expect(try engine.applyIfNeeded(wanted) == .written(attempts: 1))
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

private final class DockThatSavesOnTheWayOut: DockRestarting, @unchecked Sendable {
    enum Event: Equatable {
        case restart, wait
    }

    private let lock = NSLock()
    private let store: InMemoryDockStore
    private let saved: [String: Any]
    private var savesLeft: Int
    private var _events: [Event] = []

    init(store: InMemoryDockStore, saving saved: [String: Any], times: Int) {
        self.store = store
        self.saved = saved
        savesLeft = times
    }

    var events: [Event] {
        lock.withLock { _events }
    }

    var restarts: Int {
        events.count(where: { $0 == .restart })
    }

    func restart() throws(DockRestartError) {
        let saves = lock.withLock {
            _events.append(.restart)
            guard savesLeft > 0 else { return false }
            savesLeft -= 1
            return true
        }
        guard saves else { return }
        for (key, value) in saved {
            store.setValue(value, forKey: key)
        }
    }

    func waitUntilRunning() {
        lock.withLock { _events.append(.wait) }
    }
}

private let safari = DockApp(
    path: "/Applications/Safari.app",
    bundleId: "com.apple.Safari",
    label: "Safari"
)

private func ownTiles(of store: InMemoryDockStore) throws -> [String: Any] {
    try [DockKey.apps: #require(store.value(forKey: DockKey.apps))]
}

@Test func aDockThatSavesItsOwnTilesOnTheWayOutDoesNotUndoTheApply() throws {
    let store = try fixtureStore()
    let dock = try DockThatSavesOnTheWayOut(store: store, saving: ownTiles(of: store), times: 1)
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    let outcome = try engine.apply(target)

    #expect(try engine.read().apps == [safari])
    #expect(outcome == .written(attempts: 2))
}

@Test func reapplyingSurvivesADockThatSavesItsOwnTilesToo() throws {
    let store = try fixtureStore()
    let dock = try DockThatSavesOnTheWayOut(store: store, saving: ownTiles(of: store), times: 1)
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    let outcome = try engine.applyIfNeeded(target)

    #expect(try engine.read().apps == [safari])
    #expect(outcome == .written(attempts: 2))
}

@Test func aSettingTheDockPutBackIsWrittenAgain() throws {
    let store = try fixtureStore()
    let dock = DockThatSavesOnTheWayOut(store: store, saving: [DockKey.tilesize: 16.0], times: 1)
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.settings.tilesize = 64

    try engine.apply(target)

    #expect(try engine.read().settings.tilesize == 64)
}

@Test func aDockThatKeepsSavingItsOwnTilesIsAFailureAfterThreeWrites() throws {
    let store = try fixtureStore()
    let dock = try DockThatSavesOnTheWayOut(store: store, saving: ownTiles(of: store), times: .max)
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    #expect(throws: DockError.restart(.overwritten)) { try engine.apply(target) }
    #expect(dock.restarts == 3)
}

@Test func aDockLeftUnreadableAfterTheWriteIsNotReportedAsUntouched() throws {
    let store = try fixtureStore()
    let dock = DockThatSavesOnTheWayOut(
        store: store,
        saving: [DockKey.apps: [["tile-type": "spacer-tile"]]],
        times: .max
    )
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    var thrown: DockError?
    do {
        try engine.apply(target)
    } catch {
        thrown = error
    }

    #expect(thrown?.domainState == .changed)
}

@Test func aRepeatWaitsForTheDockThatReadTheOldTilesBeforeAskingItToQuit() throws {
    let store = try fixtureStore()
    let dock = try DockThatSavesOnTheWayOut(store: store, saving: ownTiles(of: store), times: 1)
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    try engine.apply(target)

    #expect(dock.events == [.restart, .wait, .restart])
}

@Test func anApplyTheDockKeptWaitsForNothing() throws {
    let store = try fixtureStore()
    let dock = DockThatSavesOnTheWayOut(store: store, saving: [:], times: 0)
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    try engine.apply(target)

    #expect(dock.events == [.restart])
}

@Test func aLabelTheDockRewroteDoesNotCountAsItsOwnTiles() throws {
    let store = try fixtureStore()
    var relabelled = safari
    relabelled.label = "Сафари"
    let dock = DockThatSavesOnTheWayOut(
        store: store,
        saving: [DockKey.apps: [DockWriter.tile(for: relabelled)]],
        times: .max
    )
    let engine = DockEngine(store: store, restarter: dock)
    var target = try engine.read()
    target.apps = [safari]

    let outcome = try engine.apply(target)

    #expect(outcome == .written(attempts: 1))
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    var count: Int {
        lock.withLock { _count }
    }

    func next() -> Int {
        lock.withLock {
            _count += 1
            return _count
        }
    }
}

private func seconds<Failure: Error>(_ body: () throws(Failure) -> Void) throws(Failure) -> Double {
    let started = DispatchTime.now().uptimeNanoseconds
    try body()
    return Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9
}

@Test func waitingForTheDockEndsAsSoonAsOneIsRunning() {
    let calls = CallCounter()
    let running = FakeDockProcess(quits: true, runningForChecks: .max)
    let restarter = DockRestarter(
        processes: { calls.next() > 3 ? [running] : [] },
        timeout: 2,
        pollInterval: 0.005
    )

    let elapsed = seconds { restarter.waitUntilRunning() }

    #expect(calls.count > 3)
    #expect(elapsed < 1)
}

@Test func waitingForADockThatNeverComesBackGivesUp() {
    let restarter = DockRestarter(processes: { [] }, timeout: 0.05, pollInterval: 0.005)

    let elapsed = seconds { restarter.waitUntilRunning() }

    #expect(elapsed >= 0.05)
    #expect(elapsed < 1)
}

@Test func aDockThatHasQuitButIsStillListedIsNotTakenForTheNewOne() {
    let gone = FakeDockProcess(quits: false)
    let restarter = DockRestarter(processes: { [gone] }, timeout: 0.05, pollInterval: 0.005)

    let elapsed = seconds { restarter.waitUntilRunning() }

    #expect(elapsed >= 0.05)
}

private final class StartingDockProcess: DockProcess, @unchecked Sendable {
    private let lock = NSLock()
    private let deafFor: Int
    private let quits: Bool
    private var _asks = 0

    init(deafFor: Int, quits: Bool = true) {
        self.deafFor = deafFor
        self.quits = quits
    }

    var asks: Int {
        lock.withLock { _asks }
    }

    func terminate() -> Bool {
        lock.withLock {
            _asks += 1
            return _asks > deafFor
        }
    }

    var isRunning: Bool {
        lock.withLock { !(quits && _asks > deafFor) }
    }
}

@Test func aDockTooYoungToTakeTheRequestIsAskedAgainUntilItDoes() throws {
    let young = StartingDockProcess(deafFor: 2)
    let restarter = DockRestarter(processes: { [young] }, timeout: 2, pollInterval: 0.005)

    let elapsed = try seconds { try restarter.restart() }

    #expect(young.asks == 3)
    #expect(elapsed < 1)
}

@Test func aDockThatTookTheRequestIsNotAskedTwice() {
    let stubborn = StartingDockProcess(deafFor: 0, quits: false)
    let restarter = DockRestarter(processes: { [stubborn] }, timeout: 0.05, pollInterval: 0.005)

    #expect(throws: DockRestartError.terminateRefused) { try restarter.restart() }
    #expect(stubborn.asks == 1)
}
