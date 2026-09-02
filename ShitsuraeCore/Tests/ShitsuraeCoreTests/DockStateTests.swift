import Foundation
@testable import ShitsuraeCore
import Testing

@Test func anAppSurvivesCodable() throws {
    let app = DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )
    let data = try JSONEncoder().encode(app)
    #expect(try JSONDecoder().decode(DockApp.self, from: data) == app)
}

@Test func emptySettingsHoldNoValues() {
    let settings = DockSettings()
    #expect(settings.tilesize == nil)
    #expect(settings.orientation == nil)
}

@Test func absentFieldsStayOutOfTheJSON() throws {
    var settings = DockSettings()
    settings.autohide = true
    let json = try #require(try String(data: JSONEncoder().encode(settings), encoding: .utf8))
    #expect(json.contains("autohide"))
    #expect(!json.contains("tilesize"))
}

@Test func orientationHasThreeValues() {
    #expect(DockOrientation.allCases.map(\.rawValue) == ["left", "bottom", "right"])
}

@Test func theDomainKeysMatchTheSpec() {
    #expect(DockKey.apps == "persistent-apps")
    #expect(DockKey.tilesize == "tilesize")
    #expect(DockKey.magnification == "magnification")
    #expect(DockKey.largesize == "largesize")
    #expect(DockKey.autohide == "autohide")
    #expect(DockKey.orientation == "orientation")
    #expect(DockKey.showRecents == "show-recents")
}

@Test func theDomainHasExactlySevenKeys() {
    #expect(DockKey.all.count == 7)
    #expect(Set(DockKey.all) == Set([
        DockKey.apps, DockKey.tilesize, DockKey.magnification, DockKey.largesize,
        DockKey.autohide, DockKey.orientation, DockKey.showRecents
    ]))
}

@Test func theStateSurvivesAJSONRoundTrip() throws {
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

@Test func twoBundlesSharingAnIdentifierAreTwoTiles() {
    let stable = DockApp(
        path: "/Applications/Xcode.app",
        bundleId: "com.apple.dt.Xcode",
        label: "Xcode"
    )
    let beta = DockApp(
        path: "/Applications/Xcode-beta.app",
        bundleId: "com.apple.dt.Xcode",
        label: "Xcode-beta"
    )
    let renamed = DockApp(
        path: "/Applications/Xcode.app",
        bundleId: "com.apple.dt.Xcode",
        label: "Xcode 26"
    )

    #expect(stable.id != beta.id)
    #expect(stable.id == renamed.id)
}
