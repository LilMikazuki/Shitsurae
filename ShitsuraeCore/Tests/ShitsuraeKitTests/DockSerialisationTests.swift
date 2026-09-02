import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private final class CountingEngine: DockApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = 0
    private var peak = 0

    var maxOverlap: Int {
        lock.withLock { peak }
    }

    func read() throws -> DockState {
        DockState(apps: [], settings: DockSettings())
    }

    func apply(_: DockState) throws {
        lock.withLock {
            inFlight += 1
            peak = max(peak, inFlight)
        }
        Thread.sleep(forTimeInterval: 0.05)
        lock.withLock { inFlight -= 1 }
    }

    @discardableResult
    func applyIfNeeded(_ state: DockState) throws -> Bool {
        let current = try read()
        guard state != current else { return false }
        try apply(state)
        return true
    }
}

@Test @MainActor func twoAppliesNeverTouchTheDockAtOnce() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-serial-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0), testLayout("Personal", order: 1)])
    let defaults = temporaryDefaults()
    let engine = CountingEngine()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        quitter: FakeAppQuitter()
    )
    model.reload()
    let first = try #require(model.layouts.first).id
    let second = try #require(model.layouts.last).id

    async let one: Void = model.apply(id: first)
    async let two: Void = model.apply(id: second)
    _ = await (one, two)

    #expect(engine.maxOverlap == 1, "the Dock has one arrangement and must have one writer")
}

@Test @MainActor func theBusyFlagClearsAfterAFailedApply() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-serial-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0)])
    let defaults = temporaryDefaults()
    let engine = FakeDockEngine()
    engine.applyError = DockWriteError.synchronizeFailed
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        quitter: FakeAppQuitter()
    )
    model.reload()

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(model.isChangingDock == false, "a failure must not lock the Dock out for good")
}

private final class GatedEngine: DockApplying, @unchecked Sendable {
    private let enteredGate = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)

    func waitUntilEntered() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.enteredGate.wait()
                continuation.resume()
            }
        }
    }

    func read() throws -> DockState {
        DockState(apps: [], settings: DockSettings())
    }

    func apply(_: DockState) throws {
        enteredGate.signal()
        release.wait()
    }

    @discardableResult
    func applyIfNeeded(_ state: DockState) throws -> Bool {
        try apply(state)
        return true
    }
}

@Test @MainActor func anEditMadeWhileAnApplyIsInFlightSurvivesIt() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-inflight-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    let layout = DockLayout(
        order: 0,
        name: "Work",
        apps: [DockApp(path: "/Applications/A.app", bundleId: "test.a", label: "A")],
        settings: DockSettings()
    )
    try store.save(layout)
    let defaults = temporaryDefaults()
    let engine = GatedEngine()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys()),
        quitter: FakeAppQuitter()
    )
    model.reload()
    let id = try #require(model.layouts.first).id

    let applying = Task { await model.apply(id: id) }
    await engine.waitUntilEntered()

    model.removeApp(in: id, at: 0)
    #expect(model.layouts.first?.apps.isEmpty == true)

    engine.release.signal()
    await applying.value

    #expect(model.layouts.first?.apps.isEmpty == true, "the apply must not resurrect a removed app")
    #expect(try store.load().layouts.first?.apps.isEmpty == true, "nor put it back on disk")
}

@Test @MainActor func aLayoutEditedMidApplyStopsBeingTheActiveOne() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-stale-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    try store.save(DockLayout(
        order: 0,
        name: "Work",
        apps: [DockApp(path: "/Applications/A.app", bundleId: "test.a", label: "A")],
        settings: DockSettings()
    ))
    let defaults = temporaryDefaults()
    let engine = GatedEngine()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys()),
        quitter: FakeAppQuitter()
    )
    model.reload()
    let id = try #require(model.layouts.first).id

    let applying = Task { await model.apply(id: id) }
    await engine.waitUntilEntered()
    model.removeApp(in: id, at: 0)
    engine.release.signal()
    _ = await applying.result

    #expect(model.activeLayoutID == nil, "the Dock holds the old contents, so nothing matches it")
}
