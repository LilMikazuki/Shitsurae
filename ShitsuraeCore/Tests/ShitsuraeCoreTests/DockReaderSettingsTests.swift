import Foundation
@testable import ShitsuraeCore
import Testing

/// Фикстура — санитизированный дамп домена с живой macOS 26.5.2.
/// Провенанс и список обязательных проверок в `Fixtures/README.md`.
func fixtureStore() throws -> InMemoryDockStore {
    let url = try #require(Bundle.module.url(
        forResource: "Fixtures/dock-macos-26.5.2", withExtension: "plist"
    ))
    let dict = try #require(try PropertyListSerialization.propertyList(
        from: Data(contentsOf: url), format: nil
    ) as? [String: Any])
    return InMemoryDockStore(dict)
}

@Test func tilesizeЧитаетсяКакДробное() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.settings.tilesize == 82.0)
}

@Test func прочитанныеБулевыКлючи() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.settings.autohide == true)
    #expect(state.settings.showRecents == false)
}

@Test func отсутствующийКлючЭтоНеОшибкаАNil() throws {
    let state = try DockReader(store: fixtureStore()).read()
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

@Test func неизвестнаяОриентацияЭтоНераспознанноеЗначение() {
    let store = InMemoryDockStore([DockKey.orientation: "diagonal"])
    #expect(throws: DockReadError.unsupportedValue(key: "orientation", value: "diagonal")) {
        try DockReader(store: store).read()
    }
}

/// Не строка — по-прежнему именно неверный тип, а не значение.
@Test func нестроковаяОриентацияЭтоНеверныйТип() {
    let store = InMemoryDockStore([DockKey.orientation: 42])
    #expect(throws: DockReadError.wrongType(key: "orientation", expected: "String")) {
        try DockReader(store: store).read()
    }
}

/// Текст видит пользователь, поэтому закреплён дословно.
@Test func текстНеподдерживаемогоЗначенияЗакреплён() {
    #expect("\(DockReadError.unsupportedValue(key: "orientation", value: "diagonal"))"
        == "Key \"orientation\" holds an unsupported value: diagonal.")
}

/// Пропускает словарь через сериализацию plist, чтобы получить те же
/// объекты (`CFBoolean` vs `CFNumber`), что и боевой стор из живого домена —
/// просто `true`/`1` в `[String: Any]` этого различия не гарантируют.
private func decodedPlistValues(_ dict: [String: Any]) throws -> [String: Any] {
    let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    return try #require(try PropertyListSerialization
        .propertyList(from: data, format: nil) as? [String: Any])
}

@Test func булевоЗначениеПодЧисловымКлючомЛомаетЧтение() throws {
    let store = try InMemoryDockStore(decodedPlistValues([DockKey.tilesize: true]))
    #expect(throws: DockReadError.wrongType(key: "tilesize", expected: "Number")) {
        try DockReader(store: store).read()
    }
}

@Test func числоПодБулевымКлючомЛомаетЧтение() throws {
    let store = try InMemoryDockStore(decodedPlistValues([DockKey.autohide: 1]))
    #expect(throws: DockReadError.wrongType(key: "autohide", expected: "Bool")) {
        try DockReader(store: store).read()
    }
}
