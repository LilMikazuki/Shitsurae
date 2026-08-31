import Foundation
@testable import ShitsuraeCore
import Testing

@Test func aTileIsBuiltInTheDockFormat() throws {
    let app = DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )
    let tile = DockWriter.tile(for: app)
    #expect(tile["tile-type"] as? String == "file-tile")
    let data = try #require(tile["tile-data"] as? [String: Any])
    let fileData = try #require(data["file-data"] as? [String: Any])
    #expect(fileData["_CFURLString"] as? String == "file:///Applications/Safari.app/")
    #expect(fileData["_CFURLStringType"] as? Int == 15)
    #expect(data["file-label"] as? String == "Safari")
    #expect(data["bundle-identifier"] as? String == "com.apple.Safari")
}

@Test func aSpaceInAPathIsEncodedOnWrite() throws {
    let app = DockApp(path: "/Applications/Some App.app", bundleId: "com.x.y", label: "Some App")
    let data = try #require(DockWriter.tile(for: app)["tile-data"] as? [String: Any])
    let fileData = try #require(data["file-data"] as? [String: Any])
    #expect(fileData["_CFURLString"] as? String == "file:///Applications/Some%20App.app/")
}

@Test func absentSettingsLeaveNoKeyBehind() throws {
    let state = try DockReader(store: fixtureStore()).read()
    let target = InMemoryDockStore([:])
    try DockWriter(store: target).write(state)
    #expect(target.value(forKey: DockKey.orientation) == nil)
    #expect(target.value(forKey: DockKey.magnification) == nil)
    #expect(target.value(forKey: DockKey.largesize) == nil)
    #expect(target.value(forKey: DockKey.autohide) as? Bool == true)
}

@Test func onlySevenKeysAreWritten() throws {
    let state = try DockReader(store: fixtureStore()).read()
    let target = InMemoryDockStore([:])
    try DockWriter(store: target).write(state)
    #expect(Set(target.snapshot.keys).isSubset(of: Set(DockKey.all)))
}

@Test func aSettingTheLayoutLacksIsClearedRatherThanInherited() throws {
    let target = InMemoryDockStore([
        DockKey.orientation: "left",
        DockKey.magnification: true,
        DockKey.tilesize: 64.0
    ])

    try DockWriter(store: target).write(DockState(apps: [], settings: DockSettings()))

    #expect(
        target.value(forKey: DockKey.orientation) == nil,
        "one layout must not leak into another"
    )
    #expect(target.value(forKey: DockKey.magnification) == nil)
    #expect(target.value(forKey: DockKey.tilesize) == nil)
}
