import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private let realAppPath = "/System/Library/CoreServices/Finder.app"

@MainActor
private func model(
    quitter: FakeAppQuitter,
    quitsOtherApps: Bool,
    apps: [String]
) throws -> (AppModel, DockLayout) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-autoquit-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    let layout = DockLayout(
        order: 0,
        name: "Work",
        apps: apps.map { DockApp(path: realAppPath, bundleId: $0, label: $0) },
        settings: DockSettings()
    )
    try store.saveAll([layout])
    let defaults = temporaryDefaults()
    let backup = DockBackup(
        directory: dir.appendingPathComponent("backup"),
        domain: dir.appendingPathComponent("domain.plist").path
    )
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: FakeDockEngine(), defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults),
        quitter: quitter,
        defaults: defaults
    )
    model.reload()
    model.quitsOtherApps = quitsOtherApps
    return try (model, #require(model.layouts.first))
}

@Test @MainActor func applyingQuitsOnlyTheAppsOutsideTheLayout() async throws {
    let quitter = FakeAppQuitter(running: ["a.app", "b.app", "stray.app"])
    let (model, layout) = try model(
        quitter: quitter,
        quitsOtherApps: true,
        apps: ["a.app", "b.app"]
    )

    await model.apply(id: layout.id)

    #expect(quitter.quitted == ["stray.app"])
}

@Test @MainActor func applyingQuitsNothingWhenTheSettingIsOff() async throws {
    let quitter = FakeAppQuitter(running: ["a.app", "stray.app"])
    let (model, layout) = try model(quitter: quitter, quitsOtherApps: false, apps: ["a.app"])

    await model.apply(id: layout.id)

    #expect(quitter.quitted.isEmpty)
}

@Test @MainActor func aFailedApplyQuitsNothing() async throws {
    let quitter = FakeAppQuitter(running: ["stray.app"])
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-autoquit-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    try store.saveAll([testLayout("Work", order: 0)])
    let defaults = temporaryDefaults()
    let engine = FakeDockEngine()
    engine.applyError = DockWriteError.synchronizeFailed
    let backup = DockBackup(
        directory: dir.appendingPathComponent("backup"),
        domain: dir.appendingPathComponent("domain.plist").path
    )
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: engine, defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults),
        quitter: quitter,
        defaults: defaults
    )
    model.reload()
    model.quitsOtherApps = true

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted.isEmpty, "a Dock that did not change must not cost the user their apps")
}

@Test @MainActor func theSettingSurvivesRecreatingTheModel() {
    let defaults = temporaryDefaults()
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-autoquit-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    let backup = DockBackup(
        directory: dir.appendingPathComponent("backup"),
        domain: dir.appendingPathComponent("domain.plist").path
    )
    func make() -> AppModel {
        AppModel(
            store: store,
            switcher: SwitchService(engine: FakeDockEngine(), defaults: defaults),
            restorer: RestoreService(
                backup: backup,
                restarter: FakeRestarter(),
                defaults: defaults
            ),
            quitter: FakeAppQuitter(),
            defaults: defaults
        )
    }
    #expect(make().quitsOtherApps == false)
    make().quitsOtherApps = true
    #expect(make().quitsOtherApps)
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
    let (model, layout) = try model(quitter: quitter, quitsOtherApps: true, apps: [])

    await model.apply(id: layout.id)

    #expect(quitter.quitted.isEmpty, "an empty layout must not read as \"quit everything\"")
}

@Test @MainActor func aLayoutWhoseAppsAreAllGoneQuitsNothing() async throws {
    let quitter = FakeAppQuitter(running: ["gone.a", "stray.app"])
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-gone-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    let layout = DockLayout(
        order: 0,
        name: "Work",
        apps: [DockApp(
            path: dir.appendingPathComponent("Gone.app").path,
            bundleId: "gone.a",
            label: "Gone"
        )],
        settings: DockSettings()
    )
    try store.save(layout)
    let defaults = temporaryDefaults()
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: FakeDockEngine(), defaults: defaults),
        restorer: RestoreService(
            backup: DockBackup(
                directory: dir.appendingPathComponent("backup"),
                domain: dir.appendingPathComponent("domain.plist").path
            ),
            restarter: FakeRestarter(),
            defaults: defaults
        ),
        shortcuts: ShortcutRecorder(hotkeys: InMemoryHotkeys()),
        quitter: quitter,
        defaults: defaults
    )
    model.reload()
    model.quitsOtherApps = true

    try await model.apply(id: #require(model.layouts.first).id)

    #expect(quitter.quitted.isEmpty, "an empty Dock must not read as \"quit everything\"")
}
