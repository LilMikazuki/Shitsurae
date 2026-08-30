import Foundation
@testable import ShitsuraeCore
import Testing

@Test func приложениеПереживаетCodable() throws {
    let app = DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )
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
    let json = try #require(try String(data: JSONEncoder().encode(settings), encoding: .utf8))
    #expect(json.contains("autohide"))
    #expect(!json.contains("tilesize"))
}

@Test func ориентацияИмеетТриЗначения() {
    #expect(DockOrientation.allCases.map(\.rawValue) == ["left", "bottom", "right"])
}

/// Литералы всех семи ключей прибиты здесь целиком и намеренно. Читатель,
/// писатель и round-trip ходят через одни и те же константы, поэтому опечатка
/// в любой из них никакому другому тесту не видна: домен молча получил бы
/// мусорный ключ, а настоящий ключ пользователя остался бы нетронутым.
@Test func ключиДоменаСовпадаютСоСпекой() {
    #expect(DockKey.apps == "persistent-apps")
    #expect(DockKey.tilesize == "tilesize")
    #expect(DockKey.magnification == "magnification")
    #expect(DockKey.largesize == "largesize")
    #expect(DockKey.autohide == "autohide")
    #expect(DockKey.orientation == "orientation")
    #expect(DockKey.showRecents == "show-recents")
}

@Test func всеКлючиДоменаЭтоРовноСемь() {
    #expect(DockKey.all.count == 7)
    #expect(Set(DockKey.all) == Set([
        DockKey.apps, DockKey.tilesize, DockKey.magnification, DockKey.largesize,
        DockKey.autohide, DockKey.orientation, DockKey.showRecents
    ]))
}

@Test func состояниеПереживаетJSONRoundTrip() throws {
    var settings = DockSettings()
    settings.tilesize = 48.0
    settings.largesize = 64.0
    settings.magnification = true
    settings.autohide = false
    settings.orientation = .right
    settings.showRecents = false
    let populated = DockState(
        apps: [DockApp(
            path: "/Applications/Safari.app",
            bundleId: "com.apple.Safari",
            label: "Safari"
        )],
        settings: settings
    )
    let populatedData = try JSONEncoder().encode(populated)
    #expect(try JSONDecoder().decode(DockState.self, from: populatedData) == populated)

    // Пропущенное в JSON поле должно остаться `nil`, а не превратиться
    // в значение по умолчанию — иначе предпросмотр `--dry-run` соврал бы
    // о настройках, которые пользователь не собирался менять.
    let omitted = DockState(apps: [], settings: DockSettings())
    let omittedData = try JSONEncoder().encode(omitted)
    let decoded = try JSONDecoder().decode(DockState.self, from: omittedData)
    #expect(decoded == omitted)
    #expect(decoded.settings.tilesize == nil)
    #expect(decoded.settings.largesize == nil)
    #expect(decoded.settings.magnification == nil)
    #expect(decoded.settings.autohide == nil)
    #expect(decoded.settings.orientation == nil)
    #expect(decoded.settings.showRecents == nil)
}
