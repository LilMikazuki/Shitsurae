import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func appDirectory(for bundleId: String) -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-autoquit-apps")
        .appendingPathComponent("\(bundleId).app")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}

private func layout(
    _ name: String,
    order: Int,
    apps: [String],
    quitsOtherApps: Bool
) -> DockLayout {
    DockLayout(
        order: order,
        name: name,
        apps: apps.map { DockApp(path: appDirectory(for: $0), bundleId: $0, label: $0) },
        settings: DockSettings(),
        quitsOtherApps: quitsOtherApps
    )
}

private func temporaryStore() -> (directory: URL, store: LayoutStore) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-autoquit-\(UUID().uuidString)")
    return (directory, LayoutStore(directory: directory))
}

@MainActor
private func makeModel(
    store: LayoutStore,
    quitter: any AppQuitting,
    engine: FakeDockEngine = FakeDockEngine()
) -> AppModel {
    let defaults = temporaryDefaults()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys()),
        quitter: quitter
    )
    model.reload()
    return model
}

@Test @MainActor func applyingQuitsOnlyTheAppsOutsideTheLayout() async throws {
    let quitter = FakeAppQuitter(running: ["a.app", "b.app", "stray.app"])
    let (_, store) = temporaryStore()
    try store.save(layout("Work", order: 0, apps: ["a.app", "b.app"], quitsOtherApps: true))
    let model = makeModel(store: store, quitter: quitter)

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted == ["stray.app"])
}

@Test @MainActor func applyingQuitsNothingWhenTheLayoutHasTheSettingOff() async throws {
    let quitter = FakeAppQuitter(running: ["a.app", "stray.app"])
    let (_, store) = temporaryStore()
    try store.save(layout("Work", order: 0, apps: ["a.app"], quitsOtherApps: false))
    let model = makeModel(store: store, quitter: quitter)

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted.isEmpty)
}

@Test @MainActor func applyingALayoutUsesItsOwnSettingNotAnotherLayouts() async throws {
    let quitter = FakeAppQuitter(running: ["a.app", "stray.app"])
    let (_, store) = temporaryStore()
    let quiet = layout("Quiet", order: 0, apps: ["a.app"], quitsOtherApps: false)
    let strict = layout("Strict", order: 1, apps: ["a.app"], quitsOtherApps: true)
    try store.saveAll([quiet, strict])
    let model = makeModel(store: store, quitter: quitter)

    await model.apply(id: quiet.id)
    #expect(quitter.quitted.isEmpty, "the other layout's setting must not leak into this apply")

    await model.apply(id: strict.id)
    #expect(quitter.quitted == ["stray.app"])
}

@Test @MainActor func aFailedApplyQuitsNothing() async throws {
    let quitter = FakeAppQuitter(running: ["stray.app"])
    let (_, store) = temporaryStore()
    try store.save(layout("Work", order: 0, apps: ["a.app"], quitsOtherApps: true))
    let engine = FakeDockEngine()
    engine.applyError = DockWriteError.synchronizeFailed
    let model = makeModel(store: store, quitter: quitter, engine: engine)

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted.isEmpty, "a Dock that did not change must not cost the user their apps")
}

@Test @MainActor func theSettingIsSavedWithItsLayout() throws {
    let (_, store) = temporaryStore()
    try store.save(layout("Work", order: 0, apps: ["a.app"], quitsOtherApps: false))
    let first = makeModel(store: store, quitter: FakeAppQuitter())

    try first.setQuitsOtherApps(id: #require(first.layouts.first).id, true)

    let second = makeModel(store: store, quitter: FakeAppQuitter())
    #expect(second.layouts.map(\.quitsOtherApps) == [true])
}

@Test @MainActor func turningAutoQuitOnKeepsTheActiveLayoutActive() async throws {
    let (_, store) = temporaryStore()
    try store.save(layout("Work", order: 0, apps: ["a.app"], quitsOtherApps: false))
    let model = makeModel(store: store, quitter: FakeAppQuitter())
    let id = try #require(model.layouts.first).id
    await model.apply(id: id)
    #expect(model.activeLayoutID == id)

    model.setQuitsOtherApps(id: id, true)

    #expect(
        model.activeLayoutID == id,
        "the Dock still holds this layout; only its setting changed"
    )
    #expect(model.layouts.first?.quitsOtherApps == true)
}

@Test func theQuitFilterSparesFinderTheAppItselfAndBackgroundAgents() {
    let mine = "io.github.lilmikazuki.Shitsurae"
    #expect(WorkspaceAppQuitter.isQuittable(
        bundleId: "com.example.editor",
        policy: .regular,
        mine: mine
    ))
    #expect(!WorkspaceAppQuitter.isQuittable(
        bundleId: "com.apple.finder",
        policy: .regular,
        mine: mine
    ))
    #expect(!WorkspaceAppQuitter.isQuittable(bundleId: mine, policy: .regular, mine: mine))
    #expect(!WorkspaceAppQuitter.isQuittable(
        bundleId: "com.example.agent",
        policy: .accessory,
        mine: mine
    ))
    #expect(!WorkspaceAppQuitter.isQuittable(
        bundleId: "com.example.hidden",
        policy: .prohibited,
        mine: mine
    ))
    #expect(!WorkspaceAppQuitter.isQuittable(bundleId: nil, policy: .regular, mine: mine))
}

@Test @MainActor func anEmptyLayoutQuitsNothing() async throws {
    let quitter = FakeAppQuitter(running: ["a.app", "b.app"])
    let (_, store) = temporaryStore()
    try store.save(layout("Work", order: 0, apps: [], quitsOtherApps: true))
    let model = makeModel(store: store, quitter: quitter)

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted.isEmpty, "an empty layout must not read as \"quit everything\"")
}

@Test @MainActor func aLayoutWhoseAppsAreAllGoneQuitsNothing() async throws {
    let quitter = FakeAppQuitter(running: ["gone.a", "stray.app"])
    let (directory, store) = temporaryStore()
    try store.save(DockLayout(
        order: 0,
        name: "Work",
        apps: [DockApp(
            path: directory.appendingPathComponent("Gone.app").path,
            bundleId: "gone.a",
            label: "Gone"
        )],
        settings: DockSettings(),
        quitsOtherApps: true
    ))
    let model = makeModel(store: store, quitter: quitter)

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted.isEmpty, "an empty Dock must not read as \"quit everything\"")
}
