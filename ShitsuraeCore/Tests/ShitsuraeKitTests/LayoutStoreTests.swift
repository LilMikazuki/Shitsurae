import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func layout(_ name: String, order: Int) -> DockLayout {
    var settings = DockSettings()
    settings.tilesize = 48
    settings.autohide = true
    settings.orientation = .bottom
    return DockLayout(
        order: order,
        name: name,
        apps: [DockApp(
            path: "/Applications/Safari.app",
            bundleId: "com.apple.Safari",
            label: "Safari"
        )],
        settings: settings
    )
}

@Test func aLayoutSurvivesCodable() throws {
    let original = layout("Work", order: 0)
    let data = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode(DockLayout.self, from: data) == original)
}

@Test func theAutoQuitFlagSurvivesCodable() throws {
    var original = layout("Work", order: 0)
    original.quitsOtherApps = true
    let data = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode(DockLayout.self, from: data).quitsOtherApps)
}

@Test func aLayoutFileWithoutTheSettingReadsAsOff() throws {
    let directory = try temporaryDirectory()
    let store = LayoutStore(directory: directory)
    var saved = layout("Work", order: 0)
    saved.quitsOtherApps = true
    try store.save(saved)
    let file = try #require(
        try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "json" }
    )
    var json = try #require(
        try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
    )
    #expect(json.removeValue(forKey: "quitsOtherApps") as? Bool == true)
    try JSONSerialization.data(withJSONObject: json).write(to: file)

    let loaded = try store.load()

    #expect(loaded.unreadable.isEmpty)
    #expect(loaded.layouts.map(\.quitsOtherApps) == [false])
}

@Test func aLayoutBuildsDockStateFromItsOwnFields() {
    let p = layout("Work", order: 0)
    #expect(p.dockState.apps == p.apps)
    #expect(p.dockState.settings == p.settings)
}

@Test func aMissingDirectoryYieldsAnEmptyList() throws {
    let store = LayoutStore(directory: FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-no-such-\(UUID().uuidString)"))
    #expect(try store.load().layouts.isEmpty)
}

@Test func aSavedLayoutReadsBack() throws {
    let store = try LayoutStore(directory: temporaryDirectory())
    let p = layout("Work", order: 0)
    try store.save(p)
    #expect(try store.load().layouts == [p])
}

@Test func layoutsComeBackInOrder() throws {
    let store = try LayoutStore(directory: temporaryDirectory())
    try store.save(layout("Third", order: 2))
    try store.save(layout("First", order: 0))
    try store.save(layout("Second", order: 1))
    #expect(try store.load().layouts.map(\.name) == ["First", "Second", "Third"])
}

@Test func deletingRemovesOnlyItsOwnFile() throws {
    let store = try LayoutStore(directory: temporaryDirectory())
    let keep = layout("Keep", order: 0)
    let drop = layout("Drop", order: 1)
    try store.saveAll([keep, drop])
    try store.delete(id: drop.id)
    #expect(try store.load().layouts == [keep])
}

@Test func deletingSomethingMissingDoesNotThrow() throws {
    let store = try LayoutStore(directory: temporaryDirectory())
    try store.delete(id: UUID())
}

@Test func aCorruptFileNeitherBreaksTheListNorVanishesSilently() throws {
    let dir = try temporaryDirectory()
    let store = LayoutStore(directory: dir)
    try store.save(layout("Good", order: 0))
    try Data("not json".utf8).write(to: dir.appendingPathComponent("broken.json"))

    let loaded = try store.load()
    #expect(loaded.layouts.map(\.name) == ["Good"])
    #expect(loaded.unreadable == ["broken.json"])
}

@Test func theDirectoryIsLayoutsUnlessOnlyTheLegacyOneExists() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-resolve-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(LayoutStore.directory(under: root).lastPathComponent == "layouts")

    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("presets"), withIntermediateDirectories: true
    )
    #expect(
        LayoutStore.directory(under: root).lastPathComponent == "presets",
        "a failed migration must not read as an empty library"
    )

    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("layouts"), withIntermediateDirectories: true
    )
    #expect(LayoutStore.directory(under: root).lastPathComponent == "layouts")
}

@Test func theLegacyDirectoryMovesOnceAndOnlyWhenItIsTheOnlyOne() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-migrate-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("presets")
    let current = root.appendingPathComponent("layouts")

    try LayoutStore(directory: legacy).save(testLayout("Work", order: 0))
    #expect(LayoutStore.migrate(from: legacy, to: current))
    #expect(try LayoutStore(directory: current).load().layouts.count == 1)
    #expect(FileManager.default.fileExists(atPath: legacy.path) == false)

    #expect(LayoutStore.migrate(from: legacy, to: current) == false, "nothing left to move")
}

@Test func migrationLeavesAnExistingDirectoryAlone() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-migrate-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("presets")
    let current = root.appendingPathComponent("layouts")

    try LayoutStore(directory: legacy).save(testLayout("Old", order: 0))
    try LayoutStore(directory: current).save(testLayout("New", order: 0))

    #expect(LayoutStore.migrate(from: legacy, to: current) == false)
    #expect(try LayoutStore(directory: current).load().layouts.first?.name == "New")
}

@Test func aHandEditedFileCannotSmuggleInATwin() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-twins-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let twin = DockApp(path: "/Applications/A.app", bundleId: "test.a", label: "A")
    let other = DockApp(path: "/Applications/B.app", bundleId: "test.b", label: "B")
    let layout = DockLayout(
        order: 0, name: "Work", apps: [twin, other, twin], settings: DockSettings()
    )
    try Data(JSONEncoder().encode(layout))
        .write(to: dir.appendingPathComponent("\(layout.id.uuidString).json"))

    let loaded = try LayoutStore(directory: dir).load().layouts

    #expect(loaded.first?.apps.map(\.path) == ["/Applications/A.app", "/Applications/B.app"])
}

@Test func aLayoutFileMayHoldTwoTilesSharingABundleIdentifier() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-shared-id-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = LayoutStore(directory: dir)
    try store.save(DockLayout(
        order: 0,
        name: "Work",
        apps: [
            DockApp(
                path: "/Applications/Xcode.app",
                bundleId: "com.apple.dt.Xcode",
                label: "Xcode"
            ),
            DockApp(
                path: "/Applications/Xcode-beta.app",
                bundleId: "com.apple.dt.Xcode",
                label: "Xcode-beta"
            )
        ],
        settings: DockSettings()
    ))

    #expect(try store.load().layouts.first?.apps.count == 2)
}
