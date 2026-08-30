import Foundation
import Testing
@testable import ShitsuraeCore

private final class FakeRestarter: DockRestarting {
    var restarts = 0
    func restart() { restarts += 1 }
}

private func временнаяПапка() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-engine-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func применениеПишетДелаетБэкапИПерезапускает() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try fixtureStore()
    let backup = DockBackup(directory: dir)
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: backup, restarter: restarter)

    var target = try engine.read()
    target.apps = [DockApp(path: "/Applications/Safari.app", bundleId: "com.apple.Safari", label: "Safari")]
    try engine.apply(target)

    #expect(try engine.read().apps.count == 1)
    #expect(backup.exists == true)
    #expect(restarter.restarts == 1)
}

@Test func нечитаемыйДоменЗапрещаетЗапись() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    // Домен, который мы не умеем разбирать: tilesize строкой.
    let store = InMemoryDockStore([DockKey.tilesize: "большой"])
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: DockBackup(directory: dir), restarter: restarter)

    #expect(throws: DockReadError.self) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    // Ничего не записано и Dock не тронут.
    #expect(store.value(forKey: DockKey.apps) == nil)
    #expect(restarter.restarts == 0)
    #expect(DockBackup(directory: dir).exists == false)
}

@Test func повторноеПрименениеНеДелаетВторойБэкап() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let engine = DockEngine(
        store: try fixtureStore(),
        backup: DockBackup(directory: dir),
        restarter: FakeRestarter())
    let state = try engine.read()
    try engine.apply(state)
    let first = try Data(contentsOf: DockBackup(directory: dir).backupURL)
    try engine.apply(state)
    #expect(try Data(contentsOf: DockBackup(directory: dir).backupURL) == first)
}
