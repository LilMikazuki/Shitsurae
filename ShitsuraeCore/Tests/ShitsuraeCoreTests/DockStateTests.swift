import Foundation
import Testing
@testable import ShitsuraeCore

@Test func приложениеПереживаетCodable() throws {
    let app = DockApp(path: "/Applications/Safari.app", bundleId: "com.apple.Safari", label: "Safari")
    let data = try JSONEncoder().encode(app)
    #expect(try JSONDecoder().decode(DockApp.self, from: data) == app)
}

@Test func пустыеНастройкиНеСодержатЗначений() {
    let settings = DockSettings()
    #expect(settings.tilesize == nil)
    #expect(settings.orientation == nil)
}

@Test func отсутствующиеПоляНеПопадаютВJSON() throws {
    var settings = DockSettings()
    settings.autohide = true
    let json = try #require(String(data: try JSONEncoder().encode(settings), encoding: .utf8))
    #expect(json.contains("autohide"))
    #expect(!json.contains("tilesize"))
}

@Test func ориентацияИмеетТриЗначения() {
    #expect(DockOrientation.allCases.map(\.rawValue) == ["left", "bottom", "right"])
}

@Test func ключиДоменаСовпадаютСоСпекой() {
    #expect(DockKey.apps == "persistent-apps")
    #expect(DockKey.showRecents == "show-recents")
    #expect(DockKey.tilesize == "tilesize")
}
