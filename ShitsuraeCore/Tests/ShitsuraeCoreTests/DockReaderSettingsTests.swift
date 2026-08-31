import Foundation
@testable import ShitsuraeCore
import Testing

func fixtureStore() throws -> InMemoryDockStore {
    let url = try #require(Bundle.module.url(
        forResource: "Fixtures/dock-macos-26.5.2", withExtension: "plist"
    ))
    let dict = try #require(try PropertyListSerialization.propertyList(
        from: Data(contentsOf: url), format: nil
    ) as? [String: Any])
    return InMemoryDockStore(dict)
}

@Test func tilesizeReadsAsAFraction() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.settings.tilesize == 82.0)
}

@Test func readBooleanKeys() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.settings.autohide == true)
    #expect(state.settings.showRecents == false)
}

@Test func aMissingKeyIsNilRatherThanAnError() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.settings.magnification == nil)
    #expect(state.settings.largesize == nil)
    #expect(state.settings.orientation == nil)
}

@Test func aWrongTypeBreaksReading() {
    let store = InMemoryDockStore([DockKey.tilesize: "large"])
    #expect(throws: DockReadError.wrongType(key: "tilesize", expected: "Number")) {
        try DockReader(store: store).read()
    }
}

@Test func orientationIsTyped() throws {
    let store = InMemoryDockStore([DockKey.orientation: "left"])
    #expect(try DockReader(store: store).read().settings.orientation == .left)
}

@Test func anUnknownOrientationIsAnUnsupportedValue() {
    let store = InMemoryDockStore([DockKey.orientation: "diagonal"])
    #expect(throws: DockReadError.unsupportedValue(key: "orientation", value: "diagonal")) {
        try DockReader(store: store).read()
    }
}

@Test func aNonStringOrientationIsAWrongType() {
    let store = InMemoryDockStore([DockKey.orientation: 42])
    #expect(throws: DockReadError.wrongType(key: "orientation", expected: "String")) {
        try DockReader(store: store).read()
    }
}

@Test func theUnsupportedValueTextIsPinned() {
    #expect("\(DockReadError.unsupportedValue(key: "orientation", value: "diagonal"))"
        == "Key \"orientation\" holds an unsupported value: diagonal.")
}

private func decodedPlistValues(_ dict: [String: Any]) throws -> [String: Any] {
    let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    return try #require(try PropertyListSerialization
        .propertyList(from: data, format: nil) as? [String: Any])
}

@Test func aBooleanUnderANumericKeyBreaksReading() throws {
    let store = try InMemoryDockStore(decodedPlistValues([DockKey.tilesize: true]))
    #expect(throws: DockReadError.wrongType(key: "tilesize", expected: "Number")) {
        try DockReader(store: store).read()
    }
}

@Test func aNumberUnderABooleanKeyBreaksReading() throws {
    let store = try InMemoryDockStore(decodedPlistValues([DockKey.autohide: 1]))
    #expect(throws: DockReadError.wrongType(key: "autohide", expected: "Bool")) {
        try DockReader(store: store).read()
    }
}
