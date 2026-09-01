import Foundation
import Observation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

@MainActor
private func makeModel(
    engine: FakeDockEngine = FakeDockEngine(),
    layouts: [DockLayout] = [],
    hotkeys: InMemoryHotkeys = InMemoryHotkeys()
) throws -> (AppModel, LayoutStore, FakeDockEngine) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-model-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    try store.saveAll(layouts)

    let defaults = temporaryDefaults()
    let backup = DockBackup(
        directory: dir.appendingPathComponent("backup"),
        domain: randomDomain()
    )
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults),
        shortcuts: ShortcutRecorder(hotkeys: hotkeys)
    )
    model.reload()
    return (model, store, engine)
}

private func randomDomain() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-domain-\(UUID().uuidString).plist").path
}

private func writeToDomain(_ domain: String, key: String, value: String) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["write", domain, key, value]
    try p.run()
    p.waitUntilExit()
}

private func removeDomain(_ domain: String) {
    try? FileManager.default.removeItem(atPath: domain)
}

@Test @MainActor func theListIsEmptyOnFirstLaunch() throws {
    let (model, _, _) = try makeModel()
    #expect(model.layouts.isEmpty)
    #expect(model.activeLayoutID == nil)
}

@Test @MainActor func layoutsLoadInOrder() throws {
    let (model, _, _) = try makeModel(layouts: [
        testLayout("Second", order: 1),
        testLayout("First", order: 0)
    ])
    #expect(model.layouts.map(\.name) == ["First", "Second"])
}

@Test @MainActor func savingTheCurrentDockAppendsALayout() throws {
    let engine = FakeDockEngine()
    engine.stateToReturn = DockState(
        apps: [DockApp(path: "/Applications/Mail.app", bundleId: "com.apple.mail", label: "Mail")],
        settings: DockSettings()
    )
    let (model, _, _) = try makeModel(engine: engine, layouts: [testLayout("Work", order: 0)])

    try model.saveCurrentDock(named: "Focus")

    #expect(model.layouts.map(\.name) == ["Work", "Focus"])
    #expect(model.layouts.last?.order == 1)
    #expect(model.layouts.last?.apps.map(\.label) == ["Mail"])
}

@Test @MainActor func savingSelectsButDoesNotApply() throws {
    let (model, _, _) = try makeModel()
    try model.saveCurrentDock(named: "Work")

    #expect(model.selectedLayoutID == model.layouts.first?.id)
    #expect(model.activeLayoutID == nil)
    #expect(model.layouts.first?.lastUsedAt == nil)
}

@Test @MainActor func applyingMovesTheActiveMark() async throws {
    let (model, _, engine) = try makeModel(layouts: [
        testLayout("Work", order: 0),
        testLayout("Focus", order: 1)
    ])
    let focus = try #require(model.layouts.last)

    await model.apply(id: focus.id)

    #expect(model.activeLayoutID == focus.id)
    #expect(engine.applied.count == 1)
}

@Test @MainActor func aReadErrorWhileSavingRaisesAnAlert() throws {
    let engine = FakeDockEngine()
    engine.readError = DockReadError.wrongType(key: "persistent-apps", expected: "Array")
    let (model, _, _) = try makeModel(engine: engine)

    #expect(throws: (any Error).self) {
        try model.saveCurrentDock(named: "Work")
    }
    #expect(model.alert == .failure(.unreadableLayout))
    #expect(model.layouts.isEmpty)
}

@Test @MainActor func aDockSeparatorIsNotReportedAsAFormatChange() throws {
    let engine = FakeDockEngine()
    engine.readError = DockReadError.unsupportedTileType(index: 3, tileType: "spacer-tile")
    let (model, _, _) = try makeModel(engine: engine)

    #expect(throws: (any Error).self) {
        try model.saveCurrentDock(named: "Work")
    }
    #expect(model.alert == .failure(.unsupportedTile("spacer-tile")))
}

@Test @MainActor func aRestartFailureIsNotReportedAsAReadError() async throws {
    let engine = FakeDockEngine()
    engine.applyError = DockRestartError.terminateRefused
    let (model, _, _) = try makeModel(engine: engine, layouts: [testLayout("Work", order: 0)])
    let id = try #require(model.layouts.first?.id)

    await model.apply(id: id)

    #expect(model.alert == .failure(.writtenButNotApplied(.restartRefused)))
}

@Test @MainActor func aRestartFailureDoesNotSetTheActiveMark() async throws {
    let engine = FakeDockEngine()
    engine.applyError = DockRestartError.terminateRefused
    let (model, _, _) = try makeModel(engine: engine, layouts: [testLayout("Work", order: 0)])
    let id = try #require(model.layouts.first?.id)

    await model.apply(id: id)

    #expect(model.activeLayoutID == nil)
}

@Test @MainActor func aRestartFailureWhileApplyingLeavesTheActiveLayout() async throws {
    let engine = FakeDockEngine()
    let (model, _, _) = try makeModel(engine: engine, layouts: [
        testLayout("Work", order: 0),
        testLayout("Focus", order: 1)
    ])
    let work = try #require(model.layouts.first)
    let focus = try #require(model.layouts.last)

    await model.apply(id: work.id)
    #expect(model.activeLayoutID == work.id)

    engine.applyError = DockRestartError.terminateRefused
    await model.apply(id: focus.id)

    #expect(model.alert == .failure(.writtenButNotApplied(.restartRefused)))
    #expect(model.activeLayoutID == work.id)
}

@Test func anUnknownErrorCountsAsAnUnreadableLayout() {
    struct Foreign: Error {}
    #expect(ShitsuraeFailure(from: Foreign()) == .unreadableLayout)
}

@Test func everyFailureReasonIsDistinguishable() {
    let pairs: [(error: any Error, expected: ShitsuraeFailure)] = [
        (DockReadError.wrongType(key: "tilesize", expected: "Number"), .unreadableLayout),
        (DockReadError.malformedTile(index: 0, reason: "missing path"), .unreadableLayout),
        (
            DockReadError.unsupportedValue(key: "orientation", value: "diagonal"),
            .unsupportedSetting(key: "orientation", value: "diagonal")
        ),
        (
            DockReadError.unsupportedTileType(index: 3, tileType: "spacer-tile"),
            .unsupportedTile("spacer-tile")
        ),
        (DockBackupError.backupDirectoryUnavailable, .backupFailed),
        (DockBackupError.exportCouldNotStart, .backupFailed),
        (DockBackupError.exportFailed(status: 1), .backupFailed),
        (DockBackupError.exportProducedInvalidFile, .backupFailed),
        (DockBackupError.backupMissing, .restoreFailed),
        (DockBackupError.importCouldNotStart, .writtenButNotApplied(.writeIncomplete)),
        (DockBackupError.importFailed(status: 1), .writtenButNotApplied(.writeIncomplete)),
        (DockBackupError.importDidNotApply, .writtenButNotApplied(.writeIncomplete)),
        (DockWriteError.synchronizeFailed, .writeFailed),
        (DockRestartError.terminateRefused, .writtenButNotApplied(.restartRefused))
    ]

    for (error, expected) in pairs {
        #expect(ShitsuraeFailure(from: error) == expected)
    }

    var produced: [ShitsuraeFailure] = []
    for (error, _) in pairs {
        let reason = ShitsuraeFailure(from: error)
        if !produced.contains(reason) {
            produced.append(reason)
        }
    }

    #expect(
        produced.count == 8,
        "eight distinct reasons; collapsing any two would hide a difference from the user"
    )
}

@Test @MainActor func deletingTheActiveLayoutClearsTheMark() async throws {
    let (model, _, _) = try makeModel()
    try model.saveCurrentDock(named: "Work")
    let id = try #require(model.layouts.first?.id)
    await model.apply(id: id)
    #expect(model.activeLayoutID == id)
    model.selectedLayoutID = id

    model.deleteSelected()

    #expect(model.layouts.isEmpty)
    #expect(model.activeLayoutID == nil)
}

@Test @MainActor func deletingAnInactiveLayoutKeepsTheMark() async throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    try model.saveCurrentDock(named: "Focus")
    let focusID = try #require(model.layouts.first(where: { $0.name == "Focus" })?.id)
    await model.apply(id: focusID)
    let workID = try #require(model.layouts.first(where: { $0.id != focusID })?.id)

    model.selectedLayoutID = workID
    model.deleteSelected()

    #expect(model.layouts.map(\.name) == ["Focus"])
    #expect(model.activeLayoutID == focusID)
}

@Test @MainActor func renamingChangesTheNameAndSurvivesAReload() throws {
    let (model, store, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    let id = try #require(model.layouts.first?.id)

    model.rename(id: id, to: "  Focus  ")

    #expect(model.layouts.first?.name == "Focus")
    #expect(try store.load().layouts.first?.name == "Focus")
}

@Test @MainActor func anEmptyRenameKeepsTheOldName() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    let id = try #require(model.layouts.first?.id)

    model.rename(id: id, to: "   ")

    #expect(model.layouts.first?.name == "Work")
}

@Test @MainActor func restoreIsUnavailableWithoutABackup() throws {
    let (model, _, _) = try makeModel()
    #expect(model.canRestore == false)
}

@Test @MainActor func deleteAlertNamesTheSelectedLayout() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    let id = try #require(model.layouts.first?.id)
    model.selectedLayoutID = id

    model.askDelete()

    #expect(model.alert == .delete(id: id, name: "Work"))
}

@Test @MainActor func confirmingDeleteRemovesTheLayoutTheDialogNamed() async throws {
    let (model, _, _) = try makeModel(layouts: [
        testLayout("Work", order: 0),
        testLayout("Personal", order: 1)
    ])
    let work = try #require(model.layouts.first { $0.name == "Work" }).id
    let personal = try #require(model.layouts.first { $0.name == "Personal" }).id
    model.selectedLayoutID = work
    model.askDelete()

    model.selectedLayoutID = personal
    await model.confirmAlert()

    #expect(model.layouts.map(\.name) == ["Personal"], "the dialog named Work; Work must go")
}

@Test @MainActor func deleteAlertDoesNotAppearWithoutASelection() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    model.selectedLayoutID = nil

    model.askDelete()

    #expect(model.alert == nil)
}

@Test @MainActor func cancellingTheRestoreAlertChangesNothing() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])

    model.askRestore()
    #expect(model.alert == .restore)

    model.dismissAlert()

    #expect(model.alert == nil)
}

@Test @MainActor func confirmingRestoreClearsTheActiveMarkOnSuccess() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-model-restore-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let domain = randomDomain()
    defer { removeDomain(domain) }
    try writeToDomain(domain, key: "marker", value: "original")

    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0)])
    let defaults = temporaryDefaults()
    let engine = FakeDockEngine()
    let backup = DockBackup(directory: dir.appendingPathComponent("backup"), domain: domain)
    try backup.createIfNeeded()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults)
    )
    model.reload()
    let layout = try #require(model.layouts.first)

    await model.apply(id: layout.id)
    #expect(model.activeLayoutID == layout.id)

    model.askRestore()
    #expect(model.alert == .restore)

    await model.confirmAlert()

    #expect(model.alert == nil)
    #expect(model.activeLayoutID == nil)
}

@Test @MainActor func aRestartFailureDuringRestoreYieldsWrittenButNotApplied() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-model-restore-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let domain = randomDomain()
    defer { removeDomain(domain) }
    try writeToDomain(domain, key: "marker", value: "original")

    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0)])
    let defaults = temporaryDefaults()
    let engine = FakeDockEngine()
    let backup = DockBackup(directory: dir.appendingPathComponent("backup"), domain: domain)
    try backup.createIfNeeded()
    let restarter = FakeRestarter()
    restarter.error = DockRestartError.terminateRefused
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: restarter, defaults: defaults)
    )
    model.reload()
    let layout = try #require(model.layouts.first)

    await model.apply(id: layout.id)
    #expect(model.activeLayoutID == layout.id)

    model.askRestore()
    await model.confirmAlert()

    #expect(model.alert == .failure(.writtenButNotApplied(.restartRefused)))
    #expect(model.activeLayoutID == layout.id)
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func raise() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isRaised: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@Test @MainActor func changingTheActiveLayoutNotifiesObservers() async throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work")])
    model.reload()
    let layout = try #require(model.layouts.first)

    let flag = Flag()
    withObservationTracking {
        _ = model.activeLayoutID
    } onChange: {
        flag.raise()
    }

    await model.apply(id: layout.id)

    #expect(model.activeLayoutID == layout.id)
    #expect(flag.isRaised, "changing the active layout did not notify observers")
}

@Test @MainActor func renamingDoesNotCreateNamesakes() throws {
    let (model, _, _) = try makeModel(layouts: [
        testLayout("Work", order: 0),
        testLayout("Personal", order: 1)
    ])
    model.reload()
    let personal = try #require(model.layouts.first { $0.name == "Personal" })

    #expect(model.rename(id: personal.id, to: "Work") == false)
    #expect(model.layouts.map(\.name).sorted() == ["Personal", "Work"])

    #expect(model.rename(id: personal.id, to: "  work  ") == false)

    #expect(model.rename(id: personal.id, to: "Personal") == true)
    #expect(model.rename(id: personal.id, to: "Focus") == true)
    #expect(model.layouts.map(\.name).sorted() == ["Focus", "Work"])
}

@Test @MainActor func anUnreadableDirectoryDoesNotWipeTheList() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-store-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0)])

    let defaults = temporaryDefaults()
    let backup = DockBackup(
        directory: dir.appendingPathComponent("backup"),
        domain: randomDomain()
    )
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: FakeDockEngine(), defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults)
    )
    model.reload()
    #expect(model.layouts.count == 1)
    #expect(model.storeUnavailable == false)

    try FileManager.default.removeItem(at: dir)
    try Data("not a directory".utf8).write(to: dir)

    model.reload()

    #expect(model.storeUnavailable, "an unreadable store must be visible")
    #expect(model.layouts.count == 1, "the list was wiped to empty")
}

@Test @MainActor func batchAddSkipsDuplicates() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    model.reload()
    let layout = try #require(model.layouts.first)
    let before = layout.apps.count

    let finder = "/System/Library/CoreServices/Finder.app"
    let added = model.addApps(in: layout.id, atPaths: [finder, finder, "/no/such.app"])

    #expect(added == 1)
    #expect(model.layouts.first?.apps.count == before + 1)
}

@Test @MainActor func aBackupAppearingNotifiesObservers() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-canrestore-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let domain = randomDomain()
    defer { removeDomain(domain) }
    try writeToDomain(domain, key: "marker", value: "original")

    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0)])
    let defaults = temporaryDefaults()
    let backup = DockBackup(directory: dir.appendingPathComponent("backup"), domain: domain)
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: FakeDockEngine(), defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults)
    )
    model.reload()
    #expect(model.canRestore == false)

    let flag = Flag()
    withObservationTracking {
        _ = model.canRestore
    } onChange: {
        flag.raise()
    }

    try backup.createIfNeeded()
    model.reload()

    #expect(model.canRestore, "a backup exists but restore is unavailable")
    #expect(flag.isRaised, "a backup appearing did not notify observers")
}

@Test @MainActor func deletingALayoutEndsARecordingForIt() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work", order: 0)])
    model.reload()
    let layout = try #require(model.layouts.first)

    model.selectedLayoutID = layout.id
    model.shortcuts.start(layout.id)
    #expect(model.shortcuts.recordingID == layout.id)

    model.deleteSelected()

    #expect(model.shortcuts.recordingID == nil, "recording for a layout that no longer exists")
    #expect(model.layouts.isEmpty)
}

@Test @MainActor func movingTheSelectionEndsARecordingLeftBehind() throws {
    let hotkeys = InMemoryHotkeys()
    let (model, _, _) = try makeModel(
        layouts: [testLayout("Work", order: 0), testLayout("Personal", order: 1)],
        hotkeys: hotkeys
    )
    let work = try #require(model.layouts.first).id
    let personal = try #require(model.layouts.last).id

    model.selectedLayoutID = work
    model.shortcuts.start(work)
    #expect(hotkeys.enabled == false)

    model.selectedLayoutID = personal

    #expect(model.shortcuts.recordingID == nil, "recording cannot outlive the screen it belongs to")
    #expect(hotkeys.enabled, "leaving the screen must give the user their shortcuts back")
}

@Test @MainActor func anEmptyListSeedsTheCurrentDockAsDock1() throws {
    let engine = FakeDockEngine()
    engine.stateToReturn = DockState(
        apps: [DockApp(
            path: "/Applications/Safari.app",
            bundleId: "com.apple.Safari",
            label: "Safari"
        )],
        settings: DockSettings()
    )
    let (model, _, _) = try makeModel(engine: engine)

    model.seedInitialLayoutIfNeeded()

    #expect(model.layouts.count == 1)
    #expect(model.layouts.first?.name == "Dock 1")
    #expect(model.layouts.first?.apps.map(\.bundleId) == ["com.apple.Safari"])
    #expect(engine.applied.isEmpty)
}

@Test @MainActor func theSeededLayoutIsMarkedActive() throws {
    let (model, _, _) = try makeModel()

    model.seedInitialLayoutIfNeeded()

    #expect(model.activeLayoutID != nil)
    #expect(model.activeLayoutID == model.layouts.first?.id)
}

@Test @MainActor func aStoreThatAlreadyHasLayoutsIsNotSeeded() throws {
    let (model, _, _) = try makeModel(layouts: [testLayout("Work")])

    model.seedInitialLayoutIfNeeded()

    #expect(model.layouts.map(\.name) == ["Work"])
    #expect(model.activeLayoutID == nil)
}

@Test @MainActor func aDockThatCannotBeReadSeedsNothingAndRaisesNoAlert() throws {
    let engine = FakeDockEngine()
    engine.readError = DockReadError.wrongType(key: "persistent-apps", expected: "Array")
    let (model, _, _) = try makeModel(engine: engine)

    model.seedInitialLayoutIfNeeded()

    #expect(model.layouts.isEmpty)
    #expect(model.alert == nil)
}

@Test @MainActor func anUnreadableStoreIsNotSeeded() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-unreadable-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    try store.save(testLayout("Work"))
    try FileManager.default.setAttributes([.posixPermissions: 0o333], ofItemAtPath: dir.path)
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: dir.path
        )
    }

    let engine = FakeDockEngine()
    let defaults = temporaryDefaults()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        restorer: RestoreService(
            backup: DockBackup(
                directory: dir.appendingPathComponent("backup"),
                domain: randomDomain()
            ),
            restarter: FakeRestarter(),
            defaults: defaults
        ),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys())
    )
    model.reload()
    #expect(model.storeUnavailable)

    model.seedInitialLayoutIfNeeded()

    #expect(engine.readCount == 0)
    #expect(model.activeLayoutID == nil)
}

@Test @MainActor func aStoreWhoseFilesCannotBeParsedIsNotSeeded() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-unparseable-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("not valid json".utf8).write(to: dir.appendingPathComponent("broken.json"))
    let store = LayoutStore(directory: dir)

    let engine = FakeDockEngine()
    let defaults = temporaryDefaults()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        restorer: RestoreService(
            backup: DockBackup(
                directory: dir.appendingPathComponent("backup"),
                domain: randomDomain()
            ),
            restarter: FakeRestarter(),
            defaults: defaults
        ),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys())
    )
    model.reload()
    #expect(model.layouts.isEmpty)
    #expect(model.unreadableFiles.isEmpty == false)
    #expect(model.storeUnavailable == false)

    model.seedInitialLayoutIfNeeded()

    #expect(engine.readCount == 0)
    #expect(model.activeLayoutID == nil)
}

private func settingsLayout(_ name: String = "Work", autohide: Bool = true) -> DockLayout {
    var settings = DockSettings()
    settings.autohide = autohide
    return DockLayout(order: 0, name: name, apps: [], settings: settings)
}

@Test @MainActor func applyingTheActiveLayoutAgainDoesNotWriteTheDock() async throws {
    let layout = settingsLayout()
    let engine = FakeDockEngine()
    let (model, _, _) = try makeModel(engine: engine, layouts: [layout])

    await model.apply(id: layout.id)
    engine.stateToReturn = layout.dockState
    await model.apply(id: layout.id)

    #expect(model.activeLayoutID == layout.id)
    #expect(engine.applied.count == 1)
}

@Test @MainActor func aLayoutThatDriftedFromTheDockIsReappliedEvenWhenActive() async throws {
    let layout = settingsLayout()
    let engine = FakeDockEngine()
    let (model, _, _) = try makeModel(engine: engine, layouts: [layout])

    await model.apply(id: layout.id)
    engine.stateToReturn = DockState(apps: [], settings: DockSettings())
    await model.apply(id: layout.id)

    #expect(engine.applied.count == 2)
}

@Test @MainActor func applyingAnInactiveLayoutAlwaysWrites() async throws {
    let first = settingsLayout("Work")
    let second = settingsLayout("Personal", autohide: false)
    let engine = FakeDockEngine()
    let (model, _, _) = try makeModel(engine: engine, layouts: [first, second])

    engine.stateToReturn = second.dockState
    await model.apply(id: second.id)

    #expect(engine.applied.count == 1)
}

@Test @MainActor func aSkippedApplyStillMarksTheLayoutUsed() async throws {
    let layout = settingsLayout()
    let engine = FakeDockEngine()
    let (model, _, _) = try makeModel(engine: engine, layouts: [layout])

    await model.apply(id: layout.id)
    engine.stateToReturn = layout.dockState
    await model.apply(id: layout.id)

    #expect(model.layouts.first?.lastUsedAt != nil)
}
