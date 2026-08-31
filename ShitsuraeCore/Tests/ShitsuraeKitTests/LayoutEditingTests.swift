import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func randomDomain() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-domain-\(UUID().uuidString).plist").path
}

@MainActor
private func makeModelWithLayout(_ paths: [String]) throws -> (AppModel, DockLayout) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-edit-\(UUID().uuidString)")
    let store = LayoutStore(directory: dir)
    let apps = paths.map {
        DockApp(path: "/Applications/\($0).app", bundleId: "test.\($0)", label: $0)
    }
    let layout = DockLayout(order: 0, name: "Work", apps: apps, settings: DockSettings())
    try store.save(layout)

    let defaults = temporaryDefaults()
    let backup = DockBackup(
        directory: dir.appendingPathComponent("backup"),
        domain: randomDomain()
    )
    let model = AppModel(
        store: store,
        switcher: SwitchService(engine: FakeDockEngine(), defaults: defaults),
        restorer: RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults)
    )
    model.reload()
    model.selectedLayoutID = layout.id
    return (model, layout)
}

@MainActor
private func contents(_ model: AppModel) -> [String] {
    model.selectedLayout?.apps.map(\.label) ?? []
}

@Test @MainActor func deletingRemovesOnlyItsOwnTile() throws {
    let (model, layout) = try makeModelWithLayout(["A", "B", "C"])
    model.removeApp(in: layout.id, at: 1)
    #expect(contents(model) == ["A", "C"])
}

@Test @MainActor func deletingOutOfBoundsBreaksNothing() throws {
    let (model, layout) = try makeModelWithLayout(["A", "B"])
    model.removeApp(in: layout.id, at: 5)
    #expect(contents(model) == ["A", "B"])
}

@Test @MainActor func movingBackwardPutsTheTileAtTheTarget() throws {
    let (model, layout) = try makeModelWithLayout(["A", "B", "C"])
    model.moveApps(in: layout.id, fromOffsets: IndexSet(integer: 2), toOffset: 0)
    #expect(contents(model) == ["C", "A", "B"])
}

@Test @MainActor func movingForwardAccountsForTheShiftAfterRemoval() throws {
    let (model, layout) = try makeModelWithLayout(["A", "B", "C"])
    model.moveApps(in: layout.id, fromOffsets: IndexSet(integer: 0), toOffset: 3)
    #expect(contents(model) == ["B", "C", "A"])
}

@Test @MainActor func editingTheContentsSurvivesAReload() throws {
    let (model, layout) = try makeModelWithLayout(["A", "B", "C"])
    model.removeApp(in: layout.id, at: 0)
    model.reload()
    #expect(contents(model) == ["B", "C"])
}

@Test @MainActor func aRealApplicationIsAddedWithItsBundleId() throws {
    let (model, layout) = try makeModelWithLayout(["A"])
    let finder = "/System/Library/CoreServices/Finder.app"

    #expect(model.addApp(in: layout.id, atPath: finder))
    #expect(model.selectedLayout?.apps.last?.bundleId == "com.apple.finder")
    #expect(model.selectedLayout?.apps.last?.path == finder)
}

@Test @MainActor func theSameAppIsNotAddedTwice() throws {
    let (model, layout) = try makeModelWithLayout([])
    let finder = "/System/Library/CoreServices/Finder.app"

    #expect(model.addApp(in: layout.id, atPath: finder))
    #expect(model.addApp(in: layout.id, atPath: finder) == false)
    #expect(contents(model).count == 1)
}

@Test @MainActor func aNonApplicationIsNotAdded() throws {
    let (model, layout) = try makeModelWithLayout(["A"])
    #expect(model.addApp(in: layout.id, atPath: "/etc/hosts") == false)
    #expect(model.addApp(in: layout.id, atPath: "/Applications/No Such App.app") == false)
    #expect(contents(model) == ["A"])
}

@Test @MainActor func insertingAtAnIndexLandsInTheRightPlace() throws {
    let (model, layout) = try makeModelWithLayout(["A", "B"])
    #expect(model.addApp(
        in: layout.id,
        atPath: "/System/Library/CoreServices/Finder.app",
        insertingAt: 1
    ))
    #expect(contents(model) == ["A", "Finder", "B"])
}

@Test @MainActor func movingRightPutsTheTileAfterItsNeighbour() throws {
    let (model, layout) = try makeModelWithLayout(["a", "b", "c"])
    model.moveApp(in: layout.id, from: 0, to: 1)
    #expect(model.layouts.first?.apps.map(\.bundleId) == ["test.b", "test.a", "test.c"])
}

@Test @MainActor func movingLeftPutsTheTileBeforeItsNeighbour() throws {
    let (model, layout) = try makeModelWithLayout(["a", "b", "c"])
    model.moveApp(in: layout.id, from: 2, to: 1)
    #expect(model.layouts.first?.apps.map(\.bundleId) == ["test.a", "test.c", "test.b"])
}

@Test @MainActor func movingAcrossSeveralTilesLandsOnTheTarget() throws {
    let (model, layout) = try makeModelWithLayout(["a", "b", "c", "d"])
    model.moveApp(in: layout.id, from: 0, to: 3)
    #expect(model.layouts.first?.apps.map(\.bundleId) == ["test.b", "test.c", "test.d", "test.a"])

    model.moveApp(in: layout.id, from: 3, to: 0)
    #expect(model.layouts.first?.apps.map(\.bundleId) == ["test.a", "test.b", "test.c", "test.d"])
}

@Test @MainActor func movingATileOntoItselfChangesNothing() throws {
    let (model, layout) = try makeModelWithLayout(["a", "b"])
    model.moveApp(in: layout.id, from: 1, to: 1)
    #expect(model.layouts.first?.apps.map(\.bundleId) == ["test.a", "test.b"])
}

@Test @MainActor func editingTheAppliedLayoutMakesItApplyableAgain() async throws {
    let (model, layout) = try makeModelWithLayout(["a", "b"])
    await model.apply(id: layout.id)
    #expect(model.activeLayoutID == layout.id)

    model.moveApp(in: layout.id, from: 0, to: 1)

    #expect(
        model.activeLayoutID == nil,
        "the Dock no longer matches the layout, so Apply has to become available again"
    )
}

@Test @MainActor func addingAnAppTheLayoutAlreadyHasKeepsItApplied() async throws {
    let (model, layout) = try makeModelWithLayout([])
    let finder = "/System/Library/CoreServices/Finder.app"
    #expect(model.addApp(in: layout.id, atPath: finder))

    await model.apply(id: layout.id)
    #expect(model.activeLayoutID == layout.id)

    #expect(model.addApp(in: layout.id, atPath: finder) == false)

    #expect(
        model.activeLayoutID == layout.id,
        "nothing changed, so the Dock still matches and the badge must stay"
    )
}
