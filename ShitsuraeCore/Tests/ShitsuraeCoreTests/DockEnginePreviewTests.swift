import Foundation
@testable import ShitsuraeCore
import Testing

private final class SilentRestarter: DockRestarting {
    func restart() throws(DockRestartError) {}
}

private func previewEngine(_ store: DockPreferenceStore) -> DockEngine {
    DockEngine(store: store, restarter: SilentRestarter())
}

@Test func previewShowsTheResultOfApplying() throws {
    let engine = try previewEngine(fixtureStore())

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
    let engine = previewEngine(store)

    var target = try engine.read()
    target.apps = []
    _ = try engine.preview(target)

    #expect(try DockReader(store: store).read() == before)
}

@Test func aLayoutClearsTheSettingsItDoesNotCarry() throws {
    let engine = try previewEngine(fixtureStore())

    let preview = try engine.preview(DockState(apps: [], settings: DockSettings()))

    #expect(
        preview.settings.tilesize == nil,
        "captured without a tile size, so restore its absence"
    )
    #expect(preview.settings.autohide == nil)
}

@Test func previewFailsOnAnUnreadableDomain() throws {
    let engine = previewEngine(InMemoryDockStore([DockKey.tilesize: "large"]))

    #expect(throws: DockError.read(.wrongType(key: DockKey.tilesize, expected: "Number"))) {
        try engine.preview(DockState(apps: [], settings: DockSettings()))
    }
}
