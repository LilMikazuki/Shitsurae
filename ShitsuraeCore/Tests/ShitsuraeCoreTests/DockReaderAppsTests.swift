import Foundation
@testable import ShitsuraeCore
import Testing

private func tile(path: String, bundleId: String, label: String) -> [String: Any] {
    [
        "tile-type": "file-tile",
        "tile-data": [
            "file-data": [
                "_CFURLString": URL(fileURLWithPath: path, isDirectory: true).absoluteString,
                "_CFURLStringType": 15
            ],
            "file-label": label,
            "bundle-identifier": bundleId
        ] as [String: Any]
    ]
}

@Test func readsEveryAppInTheFixture() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.apps.count == 4)
    #expect(state.apps.first?.path == "/System/Applications/Calendar.app")
    #expect(state.apps.first?.bundleId == "com.apple.iCal")
    #expect(state.apps.first?.label == "Calendar")
}

@Test func anAppWithoutAnIconIsNotLostFromTheDock() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.apps.map(\.bundleId).contains("com.apple.apps.launcher"))
}

@Test func aSpaceInAPathIsDecoded() throws {
    let store = InMemoryDockStore([DockKey.apps: [
        tile(path: "/Applications/Some App.app", bundleId: "com.x.y", label: "Some App")
    ]])
    let state = try DockReader(store: store).read()
    #expect(state.apps.first?.path == "/Applications/Some App.app")
}

@Test func cyrillicInAPathIsDecoded() throws {
    let store = InMemoryDockStore([DockKey.apps: [
        tile(path: "/Applications/Толк.app", bundleId: "kontur.talk", label: "Толк")
    ]])
    let state = try DockReader(store: store).read()
    #expect(state.apps.first?.path == "/Applications/Толк.app")
}

@Test func aMissingAppsKeyYieldsAnEmptyList() throws {
    let state = try DockReader(store: InMemoryDockStore([:])).read()
    #expect(state.apps.isEmpty)
}

@Test func aTileWithoutABundleIdBreaksReading() {
    let broken: [String: Any] = [
        "tile-type": "file-tile",
        "tile-data": [
            "file-data": ["_CFURLString": "file:///Applications/X.app/", "_CFURLStringType": 15],
            "file-label": "X"
        ] as [String: Any]
    ]
    let store = InMemoryDockStore([DockKey.apps: [broken]])
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "missing bundle-identifier")) {
        try DockReader(store: store).read()
    }
}

@Test func aNonArrayAppsValueIsAnError() {
    let store = InMemoryDockStore([DockKey.apps: "oops"])
    #expect(throws: DockReadError.wrongType(key: "persistent-apps", expected: "Array")) {
        try DockReader(store: store).read()
    }
}

@Test func aSpacerTileGivesAClearError() {
    let spacer: [String: Any] = [
        "tile-type": "small-spacer-tile",
        "tile-data": [:] as [String: Any]
    ]
    let store = InMemoryDockStore([DockKey.apps: [spacer]])
    #expect(throws: DockReadError.unsupportedTileType(index: 0, tileType: "small-spacer-tile")) {
        try DockReader(store: store).read()
    }
}

@Test func theUnsupportedTileTypeTextIsPinned() {
    #expect("\(DockReadError.unsupportedTileType(index: 0, tileType: "small-spacer-tile"))"
        == "Dock item #0 is a \"small-spacer-tile\", which Shitsurae does not support yet.")
}

@Test func aSeparatorAndFormatCorruptionAreDifferentErrors() {
    let spacer: [String: Any] = [
        "tile-type": "small-spacer-tile",
        "tile-data": [:] as [String: Any]
    ]
    let broken: [String: Any] = ["tile-type": "file-tile"]

    #expect(throws: DockReadError.unsupportedTileType(index: 0, tileType: "small-spacer-tile")) {
        try DockReader(store: InMemoryDockStore([DockKey.apps: [spacer]])).read()
    }
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "missing tile-data")) {
        try DockReader(store: InMemoryDockStore([DockKey.apps: [broken]])).read()
    }
}

@Test func aNonDictionaryAppsElementIsMalformed() {
    let store = InMemoryDockStore([DockKey.apps: ["oops"]])
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "tile is not a dictionary")) {
        try DockReader(store: store).read()
    }
}

@Test func aTileWithoutATileTypeBreaksReading() {
    let noType: [String: Any] = [
        "tile-data": [:] as [String: Any]
    ]
    let store = InMemoryDockStore([DockKey.apps: [noType]])
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "missing tile-type")) {
        try DockReader(store: store).read()
    }
}

@Test func aNonFileURLBreaksReading() {
    let remote: [String: Any] = [
        "tile-type": "file-tile",
        "tile-data": [
            "file-data": [
                "_CFURLString": "http://evil.example/Applications/X.app/",
                "_CFURLStringType": 15
            ],
            "file-label": "X",
            "bundle-identifier": "com.x.y"
        ] as [String: Any]
    ]
    let store = InMemoryDockStore([DockKey.apps: [remote]])
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "missing path")) {
        try DockReader(store: store).read()
    }
}
