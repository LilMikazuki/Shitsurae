import Foundation
@testable import ShitsuraeCore
import Testing

/// Round-trip проверяется на уровне `DockState`, а не байтов plist:
/// `book` и `GUID` привязаны к машине и в модель осознанно не переносятся.
@Test func состояниеПереживаетЗаписьИПовторноеЧтение() throws {
    let original = try DockReader(store: fixtureStore()).read()
    let target = InMemoryDockStore([:])
    DockWriter(store: target).write(original)
    #expect(try DockReader(store: target).read() == original)
}

@Test func всеНастройкиПереживаютRoundTrip() throws {
    var settings = DockSettings()
    settings.tilesize = 48.0
    settings.largesize = 64.0
    settings.magnification = true
    settings.autohide = false
    settings.orientation = .right
    settings.showRecents = false
    let original = DockState(
        apps: [DockApp(
            path: "/Applications/Safari.app",
            bundleId: "com.apple.Safari",
            label: "Safari"
        )],
        settings: settings
    )
    let target = InMemoryDockStore([:])
    DockWriter(store: target).write(original)
    #expect(try DockReader(store: target).read() == original)
}
