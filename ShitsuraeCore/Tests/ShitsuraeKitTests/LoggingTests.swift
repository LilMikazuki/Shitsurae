import Foundation
@testable import ShitsuraeKit
import Testing

@MainActor
private func makeLoggedModel(
    layouts: [DockLayout] = []
) throws -> (AppModel, LayoutStore, RecordingEventLog) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-logging-\(UUID().uuidString)")
    let log = RecordingEventLog()
    let store = LayoutStore(directory: dir, log: log)
    try store.saveAll(layouts)

    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: FakeDockEngine()),
        marker: ActiveLayoutMarker(defaults: temporaryDefaults()),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys(), log: log),
        log: log
    )
    model.reload()
    return (model, store, log)
}

private func sealed(_ directory: URL) throws {
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o555], ofItemAtPath: directory.path
    )
}

private func unsealed(_ directory: URL) {
    try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path
    )
}

@Test @MainActor func aFailedDeleteIsExplainedInTheLog() async throws {
    let (model, store, log) = try makeLoggedModel(layouts: [testLayout("Work")])
    let work = try #require(model.layouts.first).id
    model.page = .layout(work)
    model.askDelete()
    let shown = try #require(model.alert)
    _ = model.beginPresenting()

    try sealed(store.directory)
    defer { unsealed(store.directory) }
    await model.confirmAlert(shown)

    let failures = log.messages(.error, .layouts)
    #expect(failures.count == 1)
    #expect(failures.first?.contains(work.uuidString) == true)
    #expect(log.messages(.error, .dock).isEmpty)
}

@Test @MainActor func theLogNamesLayoutsByIdNotByName() async throws {
    let name = "Secret \(UUID().uuidString)"
    let (model, store, log) = try makeLoggedModel(layouts: [testLayout(name)])
    let id = try #require(model.layouts.first).id
    await model.apply(id: id)

    try sealed(store.directory)
    defer { unsealed(store.directory) }
    _ = model.rename(id: id, to: "Renamed")
    model.delete(id: id)

    #expect(log.messages.contains { $0.contains(id.uuidString) })
    #expect(!log.messages.contains { $0.contains(name) })
}
