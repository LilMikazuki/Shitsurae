import Foundation
import Testing
@testable import ShitsuraeCore

/// Фикстура — санитизированный дамп домена с живой macOS 26.5.2.
/// Провенанс и список обязательных проверок в `Fixtures/README.md`.
func fixtureStore() throws -> InMemoryDockStore {
    let url = try #require(Bundle.module.url(
        forResource: "Fixtures/dock-macos-26.5.2", withExtension: "plist"))
    let dict = try #require(try PropertyListSerialization.propertyList(
        from: Data(contentsOf: url), format: nil) as? [String: Any])
    return InMemoryDockStore(dict)
}

@Test func tilesizeЧитаетсяКакДробное() throws {
    let state = try DockReader(store: try fixtureStore()).read()
    #expect(state.settings.tilesize == 82.0)
}

@Test func прочитанныеБулевыКлючи() throws {
    let state = try DockReader(store: try fixtureStore()).read()
    #expect(state.settings.autohide == true)
    #expect(state.settings.showRecents == false)
}

@Test func отсутствующийКлючЭтоНеОшибкаАNil() throws {
    let state = try DockReader(store: try fixtureStore()).read()
    #expect(state.settings.magnification == nil)
    #expect(state.settings.largesize == nil)
    #expect(state.settings.orientation == nil)
}

@Test func неверныйТипЛомаетЧтение() {
    let store = InMemoryDockStore([DockKey.tilesize: "большой"])
    #expect(throws: DockReadError.wrongType(key: "tilesize", expected: "Number")) {
        try DockReader(store: store).read()
    }
}

@Test func ориентацияТипизирована() throws {
    let store = InMemoryDockStore([DockKey.orientation: "left"])
    #expect(try DockReader(store: store).read().settings.orientation == .left)
}

@Test func неизвестнаяОриентацияЭтоОшибка() {
    let store = InMemoryDockStore([DockKey.orientation: "diagonal"])
    #expect(throws: DockReadError.self) {
        try DockReader(store: store).read()
    }
}
