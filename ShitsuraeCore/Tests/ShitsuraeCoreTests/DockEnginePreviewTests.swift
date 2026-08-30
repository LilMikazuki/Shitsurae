import Foundation
@testable import ShitsuraeCore
import Testing

private final class МолчаливыйРестартер: DockRestarting {
    func restart() throws {}
}

private func превьюДвижок(_ store: DockPreferenceStore) throws -> (DockEngine, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-preview-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let engine = DockEngine(
        store: store,
        backup: DockBackup(directory: dir),
        restarter: МолчаливыйРестартер()
    )
    return (engine, dir)
}

@Test func предпросмотрПоказываетРезультатПрименения() throws {
    let (engine, dir) = try превьюДвижок(fixtureStore())
    defer { try? FileManager.default.removeItem(at: dir) }

    var target = try engine.read()
    target.apps = [DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )]

    let preview = try engine.preview(target)
    #expect(preview.apps.count == 1)
    #expect(preview.apps.first?.bundleId == "com.apple.Safari")
}

/// Главное свойство предпросмотра: исходный стор не меняется.
@Test func предпросмотрНеТрогаетИсходныйСтор() throws {
    let store = try fixtureStore()
    let before = try DockReader(store: store).read()
    let (engine, dir) = try превьюДвижок(store)
    defer { try? FileManager.default.removeItem(at: dir) }

    var target = try engine.read()
    target.apps = []
    _ = try engine.preview(target)

    #expect(try DockReader(store: store).read() == before)
}

/// Пропущенная настройка означает «не трогать», и предпросмотр обязан
/// показывать её сохранённой, а не сброшенной в дефолт.
@Test func предпросмотрСохраняетПропущенныеНастройки() throws {
    let (engine, dir) = try превьюДвижок(fixtureStore())
    defer { try? FileManager.default.removeItem(at: dir) }

    let preview = try engine.preview(DockState(apps: [], settings: DockSettings()))
    #expect(preview.settings.tilesize == 82.0)
    #expect(preview.settings.autohide == true)
}

/// Тот же гейт, что и в `apply`: непонятный домен запрещает даже предпросмотр.
@Test func предпросмотрПадаетНаНечитаемомДомене() throws {
    let (engine, dir) = try превьюДвижок(InMemoryDockStore([DockKey.tilesize: "большой"]))
    defer { try? FileManager.default.removeItem(at: dir) }

    #expect(throws: DockReadError.self) {
        try engine.preview(DockState(apps: [], settings: DockSettings()))
    }
}
