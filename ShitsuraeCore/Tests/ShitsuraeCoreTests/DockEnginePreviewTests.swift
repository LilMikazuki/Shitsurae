import Foundation
@testable import ShitsuraeCore
import Testing

private final class SilentRestarter: DockRestarting {
    func restart() throws {}
}

private func previewEngine(_ store: DockPreferenceStore) throws -> (DockEngine, DockBackup, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-preview-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let backup = DockBackup(directory: dir)
    let engine = DockEngine(
        store: store,
        backup: backup,
        restarter: SilentRestarter()
    )
    return (engine, backup, dir)
}

@Test func previewShowsTheResultOfApplying() throws {
    let (engine, _, dir) = try previewEngine(fixtureStore())
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

@Test func previewLeavesTheSourceStoreAlone() throws {
    let store = try fixtureStore()
    let before = try DockReader(store: store).read()
    let (engine, _, dir) = try previewEngine(store)
    defer { try? FileManager.default.removeItem(at: dir) }

    var target = try engine.read()
    target.apps = []
    _ = try engine.preview(target)

    #expect(try DockReader(store: store).read() == before)
}

@Test func aLayoutClearsTheSettingsItDoesNotCarry() throws {
    let (engine, _, dir) = try previewEngine(fixtureStore())
    defer { try? FileManager.default.removeItem(at: dir) }

    let preview = try engine.preview(DockState(apps: [], settings: DockSettings()))

    #expect(
        preview.settings.tilesize == nil,
        "captured without a tile size, so restore its absence"
    )
    #expect(preview.settings.autohide == nil)
}

@Test func previewFailsOnAnUnreadableDomain() throws {
    let (engine, _, dir) = try previewEngine(InMemoryDockStore([DockKey.tilesize: "large"]))
    defer { try? FileManager.default.removeItem(at: dir) }

    #expect(throws: DockReadError.self) {
        try engine.preview(DockState(apps: [], settings: DockSettings()))
    }
}

@Test func previewLeavesTheBackupAlone() throws {
    let (engine, backup, dir) = try previewEngine(fixtureStore())
    defer { try? FileManager.default.removeItem(at: dir) }

    _ = try engine.preview(DockState(apps: [], settings: DockSettings()))
    #expect(backup.exists == false)
}
