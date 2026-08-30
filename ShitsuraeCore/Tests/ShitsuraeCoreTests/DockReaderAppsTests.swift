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

@Test func читаетВсеПриложенияФикстуры() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.apps.count == 4)
    #expect(state.apps.first?.path == "/System/Applications/Calendar.app")
    #expect(state.apps.first?.bundleId == "com.apple.iCal")
    #expect(state.apps.first?.label == "Calendar")
}

/// Ключевой кейс: приложение с `LSUIElement=true` лежит в Dock обычным тайлом.
/// Терять его нельзя, см. раздел спеки про accessory-приложения.
@Test func приложениеБезИконкиВDockНеТеряется() throws {
    let state = try DockReader(store: fixtureStore()).read()
    #expect(state.apps.map(\.bundleId).contains("com.apple.apps.launcher"))
}

@Test func пробелВПутиРаскодируется() throws {
    let store = InMemoryDockStore([DockKey.apps: [
        tile(path: "/Applications/Some App.app", bundleId: "com.x.y", label: "Some App")
    ]])
    let state = try DockReader(store: store).read()
    #expect(state.apps.first?.path == "/Applications/Some App.app")
}

@Test func кириллицаВПутиРаскодируется() throws {
    let store = InMemoryDockStore([DockKey.apps: [
        tile(path: "/Applications/Толк.app", bundleId: "kontur.talk", label: "Толк")
    ]])
    let state = try DockReader(store: store).read()
    #expect(state.apps.first?.path == "/Applications/Толк.app")
}

@Test func отсутствиеКлючаПриложенийДаётПустойСписок() throws {
    let state = try DockReader(store: InMemoryDockStore([:])).read()
    #expect(state.apps.isEmpty)
}

@Test func тайлБезBundleIdЛомаетЧтение() {
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

@Test func приложенияНеМассивЭтоОшибка() {
    let store = InMemoryDockStore([DockKey.apps: "ой"])
    #expect(throws: DockReadError.wrongType(key: "persistent-apps", expected: "Array")) {
        try DockReader(store: store).read()
    }
}

@Test func тайлСпейсераДаётПонятнуюОшибку() {
    let spacer: [String: Any] = [
        "tile-type": "small-spacer-tile",
        "tile-data": [:] as [String: Any]
    ]
    let store = InMemoryDockStore([DockKey.apps: [spacer]])
    #expect(throws: DockReadError.unsupportedTileType(index: 0, tileType: "small-spacer-tile")) {
        try DockReader(store: store).read()
    }
}

/// Разделитель и порча формата должны различаться без разбора строк:
/// у пользователя с разделителями и у пользователя на новой macOS
/// разные причины и разные тексты в интерфейсе.
@Test func разделительИПорчаФорматаЭтоРазныеОшибки() {
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

/// Массив есть, но элемент в нём не словарь — это про элемент, а не про тип
/// самого ключа, и сообщение обязано называть индекс.
@Test func элементПриложенийНеСловарьЭтоМалформ() {
    let store = InMemoryDockStore([DockKey.apps: ["ой"]])
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "tile is not a dictionary")) {
        try DockReader(store: store).read()
    }
}

@Test func тайлБезTileTypeЛомаетЧтение() {
    let noType: [String: Any] = [
        "tile-data": [:] as [String: Any]
    ]
    let store = InMemoryDockStore([DockKey.apps: [noType]])
    #expect(throws: DockReadError.malformedTile(index: 0, reason: "missing tile-type")) {
        try DockReader(store: store).read()
    }
}

/// У `http://evil.example/Applications/X.app/` тоже есть правдоподобный `path`,
/// и без проверки схемы мы записали бы его обратно локальным file-URL. Из живого
/// домена такое не приходит, но молча переосмысливать чужой ввод спека запрещает.
@Test func нефайловыйURLЛомаетЧтение() {
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
