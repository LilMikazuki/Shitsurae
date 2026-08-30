import Foundation
import Testing
@testable import ShitsuraeCore

@Test func тайлСобираетсяВФорматеDock() throws {
    let app = DockApp(path: "/Applications/Safari.app", bundleId: "com.apple.Safari", label: "Safari")
    let tile = DockWriter.tile(for: app)
    #expect(tile["tile-type"] as? String == "file-tile")
    let data = try #require(tile["tile-data"] as? [String: Any])
    let fileData = try #require(data["file-data"] as? [String: Any])
    #expect(fileData["_CFURLString"] as? String == "file:///Applications/Safari.app/")
    #expect(fileData["_CFURLStringType"] as? Int == 15)
    #expect(data["file-label"] as? String == "Safari")
    #expect(data["bundle-identifier"] as? String == "com.apple.Safari")
}

@Test func пробелВПутиКодируетсяПриЗаписи() throws {
    let app = DockApp(path: "/Applications/Some App.app", bundleId: "com.x.y", label: "Some App")
    let data = try #require(DockWriter.tile(for: app)["tile-data"] as? [String: Any])
    let fileData = try #require(data["file-data"] as? [String: Any])
    #expect(fileData["_CFURLString"] as? String == "file:///Applications/Some%20App.app/")
}

@Test func отсутствующиеНастройкиНеЗаписываются() throws {
    let state = try DockReader(store: try fixtureStore()).read()
    let target = InMemoryDockStore([:])
    DockWriter(store: target).write(state)
    #expect(target.value(forKey: DockKey.orientation) == nil)
    #expect(target.value(forKey: DockKey.magnification) == nil)
    #expect(target.value(forKey: DockKey.largesize) == nil)
    #expect(target.value(forKey: DockKey.autohide) as? Bool == true)
}

@Test func записываетсяТолькоСемьКлючей() throws {
    let state = try DockReader(store: try fixtureStore()).read()
    let target = InMemoryDockStore([:])
    DockWriter(store: target).write(state)
    // В фикстуре 20 ключей домена, но нас касаются только свои.
    #expect(Set(target.snapshot.keys).isSubset(of: [
        DockKey.apps, DockKey.tilesize, DockKey.magnification, DockKey.largesize,
        DockKey.autohide, DockKey.orientation, DockKey.showRecents,
    ]))
}
