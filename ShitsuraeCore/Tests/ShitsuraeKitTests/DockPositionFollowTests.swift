import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private final class MovableDock: DockApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var state = DockState(apps: [], settings: DockSettings())
    private var writes: [DockState] = []
    private var unreadable = false
    private var holdsNextApply = false
    private let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)

    var written: [DockState] {
        lock.withLock { writes }
    }

    func move(to position: DockOrientation?) {
        change { $0.settings.orientation = position }
    }

    func change(_ edit: (inout DockState) -> Void) {
        lock.withLock { edit(&state) }
    }

    func becomeUnreadable() {
        lock.withLock { unreadable = true }
    }

    func holdNextApply() {
        lock.withLock { holdsNextApply = true }
    }

    func waitUntilEntered() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.entered.wait()
                continuation.resume()
            }
        }
    }

    func read() throws(DockError) -> DockState {
        let (failing, current) = lock.withLock { (unreadable, state) }
        if failing {
            throw .read(.unsupportedTileType(index: 0, tileType: "spacer-tile"))
        }
        return current
    }

    @discardableResult
    func apply(_ wanted: DockState) throws(DockError) -> DockApplyOutcome {
        let held = lock.withLock {
            state = wanted
            writes.append(wanted)
            let held = holdsNextApply
            holdsNextApply = false
            return held
        }
        if held {
            entered.signal()
            release.wait()
        }
        return .written(attempts: 1)
    }

    @discardableResult
    func applyIfNeeded(_ wanted: DockState) throws(DockError) -> DockApplyOutcome {
        guard try read() != wanted else { return .alreadyHeld }
        return try apply(wanted)
    }
}

private func layout(_ name: String, order: Int, position: DockOrientation?) -> DockLayout {
    var settings = DockSettings()
    settings.orientation = position
    return DockLayout(order: order, name: name, apps: [], settings: settings)
}

@MainActor
private func makeModel(
    layouts: [DockLayout],
    dock: MovableDock,
    marker: ActiveLayoutMarker = ActiveLayoutMarker(defaults: temporaryDefaults())
) throws -> (AppModel, LayoutStore, RecordingEventLog) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-position-\(UUID().uuidString)")
    let log = RecordingEventLog()
    let store = LayoutStore(directory: dir, log: log)
    try store.saveAll(layouts)
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: dock),
        marker: marker,
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys(), log: log),
        quitter: FakeAppQuitter(),
        log: log
    )
    model.reload()
    return (model, store, log)
}

private func moves(in log: RecordingEventLog) -> [String] {
    log.messages(.notice, .layouts).filter { $0.contains("took the Dock's position") }
}

@Test @MainActor func aLayoutReturnedToAfterItsDockWasMovedDoesNotMoveTheDockBack() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let focus = layout("Focus", order: 1, position: .left)
    let dock = MovableDock()
    let (model, _, _) = try makeModel(layouts: [work, focus], dock: dock)

    await model.apply(id: work.id)
    dock.move(to: .right)
    model.adoptDockPosition()
    await model.apply(id: focus.id)
    await model.apply(id: work.id)

    #expect(dock.written.last?.settings.orientation == .right)
}

@Test @MainActor func aDockMovedWhileALayoutIsActiveIsRememberedByThatLayout() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let dock = MovableDock()
    let (model, store, _) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.move(to: .right)
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .right)
    #expect(try store.load().layouts.first?.settings.orientation == .right)
}

@Test @MainActor func rememberingAMoveKeepsTheLayoutActiveAndDoesNotCountAsUsingIt() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let dock = MovableDock()
    let (model, _, _) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    let usedAt = try #require(model.layouts.first?.lastUsedAt)
    dock.move(to: .right)
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .right)
    #expect(model.activeLayoutID == work.id)
    #expect(model.layouts.first?.lastUsedAt == usedAt)
}

@Test @MainActor func aMoveCarriesOnlyThePositionIntoTheLayout() async throws {
    let work = testLayout("Work", order: 0)
    let dock = MovableDock()
    let (model, store, _) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.change {
        $0.settings.orientation = .right
        $0.settings.tilesize = 64
        $0.settings.autohide = false
        $0.apps = []
    }
    model.adoptDockPosition()

    let kept = try #require(try store.load().layouts.first)
    #expect(kept.settings.orientation == .right)
    #expect(kept.settings.tilesize == nil)
    #expect(kept.settings.autohide == true)
    #expect(kept.apps == work.apps)
}

@Test @MainActor func aMoveAfterAnUnappliedEditIsRememberedByNoLayout() async throws {
    let work = testLayout("Work", order: 0)
    let dock = MovableDock()
    let (model, store, _) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    model.removeApp(in: work.id, at: 0)
    try #require(model.activeLayoutID == nil)
    dock.move(to: .right)
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == nil)
    #expect(try store.load().layouts.first?.settings.orientation == nil)
}

@Test @MainActor func switchingLayoutsDoesNotRewriteTheLayoutBeingLeft() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let focus = layout("Focus", order: 1, position: .left)
    let dock = MovableDock()
    let (model, store, _) = try makeModel(layouts: [work, focus], dock: dock)

    await model.apply(id: work.id)
    dock.holdNextApply()
    let switching = Task { await model.apply(id: focus.id) }
    await dock.waitUntilEntered()
    model.adoptDockPosition()
    dock.release.signal()
    await switching.value

    #expect(model.layouts.first?.settings.orientation == .bottom)
    #expect(try store.load().layouts.first?.settings.orientation == .bottom)
    #expect(model.activeLayoutID == focus.id)
}

@Test @MainActor func aSignalRightAfterASwitchRecordsNothing() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let focus = layout("Focus", order: 1, position: .left)
    let dock = MovableDock()
    let (model, _, log) = try makeModel(layouts: [work, focus], dock: dock)

    await model.apply(id: work.id)
    await model.apply(id: focus.id)
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .bottom)
    #expect(model.layouts.last?.settings.orientation == .left)
    #expect(moves(in: log).isEmpty)
}

@Test @MainActor
func afterAMoveIsRememberedApplyingTheActiveLayoutAgainDoesNotWriteTheDock() async throws {
    let work = layout("Work", order: 0, position: nil)
    let dock = MovableDock()
    let (model, _, _) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.move(to: .bottom)
    model.adoptDockPosition()
    await model.apply(id: work.id)

    #expect(dock.written.count == 1)
}

@Test @MainActor func aMoveTheStoreRefusedIsNotShownAndRaisesNoAlert() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let dock = MovableDock()
    let (model, store, log) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o555], ofItemAtPath: store.directory.path
    )
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: store.directory.path
        )
    }
    dock.move(to: .right)
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .bottom)
    #expect(model.alert == nil)
    #expect(log.messages(.error, .layouts).count == 1)
}

@Test @MainActor
func aDockThatCannotBeReadAfterAMoveChangesNoLayoutAndRaisesNoAlert() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let dock = MovableDock()
    let (model, _, log) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.becomeUnreadable()
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .bottom)
    #expect(model.alert == nil)
    #expect(log.messages(.error, .dock).count == 1)
}

@Test @MainActor func aMoveMadeBeforeLaunchIsRememberedByTheLayoutThatWasActive() throws {
    let work = layout("Work", order: 0, position: .bottom)
    let marker = ActiveLayoutMarker(defaults: temporaryDefaults())
    marker.id = work.id
    let dock = MovableDock()
    dock.move(to: .right)
    let (model, store, _) = try makeModel(layouts: [work], dock: dock, marker: marker)

    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .right)
    #expect(try store.load().layouts.first?.settings.orientation == .right)
}

@Test @MainActor func aDockWhosePositionWasResetIsRememberedAsUnset() async throws {
    let work = layout("Work", order: 0, position: .right)
    let dock = MovableDock()
    let (model, store, _) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.move(to: nil)
    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == nil)
    #expect(try store.load().layouts.first?.settings.orientation == nil)
}

@Test @MainActor func aSignalWithNoNewPositionRecordsNothing() async throws {
    let work = layout("Work", order: 0, position: .bottom)
    let dock = MovableDock()
    let (model, _, log) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.move(to: .right)
    model.adoptDockPosition()
    model.adoptDockPosition()

    #expect(moves(in: log).count == 1)
}

@Test @MainActor func aMarkThatNamesAMissingLayoutChangesNoLayout() throws {
    let work = layout("Work", order: 0, position: .bottom)
    let marker = ActiveLayoutMarker(defaults: temporaryDefaults())
    marker.id = UUID()
    let dock = MovableDock()
    dock.move(to: .right)
    let (model, _, log) = try makeModel(layouts: [work], dock: dock, marker: marker)

    model.adoptDockPosition()

    #expect(model.layouts.first?.settings.orientation == .bottom)
    #expect(moves(in: log).isEmpty)
}

@Test @MainActor func theMoveIsLoggedByLayoutIdAndPositionNotByName() async throws {
    let name = "Secret \(UUID().uuidString)"
    let work = layout(name, order: 0, position: .bottom)
    let dock = MovableDock()
    let (model, _, log) = try makeModel(layouts: [work], dock: dock)

    await model.apply(id: work.id)
    dock.move(to: .right)
    model.adoptDockPosition()

    let line = try #require(moves(in: log).first)
    #expect(line.contains(work.id.uuidString))
    #expect(line.contains("right"))
    #expect(!log.messages.contains { $0.contains(name) })
}
