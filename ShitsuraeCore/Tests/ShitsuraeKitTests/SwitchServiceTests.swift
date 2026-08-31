import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

@Test func applyingHandsTheEngineTheLayoutState() throws {
    let engine = FakeDockEngine()
    let service = SwitchService(engine: engine, defaults: temporaryDefaults())
    let layout = testLayout()

    try service.apply(layout)

    #expect(engine.applied == [layout.dockState])
}

@Test func applyingRemembersTheLastLayout() throws {
    let service = SwitchService(engine: FakeDockEngine(), defaults: temporaryDefaults())
    let layout = testLayout()

    try service.apply(layout)

    #expect(service.lastAppliedLayoutID == layout.id)
}

@Test func aFailedApplyDoesNotRememberTheLayout() {
    struct Broken: Error {}
    let engine = FakeDockEngine()
    engine.applyError = Broken()
    let service = SwitchService(engine: engine, defaults: temporaryDefaults())

    #expect(throws: Broken.self) {
        try service.apply(testLayout())
    }
    #expect(service.lastAppliedLayoutID == nil)
}

@Test func theLastLayoutSurvivesRecreatingTheService() throws {
    let defaults = temporaryDefaults()
    let layout = testLayout()
    try SwitchService(engine: FakeDockEngine(), defaults: defaults).apply(layout)

    let fresh = SwitchService(engine: FakeDockEngine(), defaults: defaults)
    #expect(fresh.lastAppliedLayoutID == layout.id)
}

@Test func applyingSkipsApplicationsThatAreGoneFromDisk() throws {
    let engine = FakeDockEngine()
    let service = SwitchService(engine: engine, defaults: temporaryDefaults())
    let layout = DockLayout(
        order: 0,
        name: "Work",
        apps: [
            DockApp(
                path: "/System/Library/CoreServices/Finder.app",
                bundleId: "here",
                label: "Here"
            ),
            DockApp(path: "/Applications/No Such App.app", bundleId: "gone", label: "Gone")
        ],
        settings: DockSettings()
    )

    try service.apply(layout)

    #expect(
        engine.applied.last?.apps.map(\.bundleId) == ["here"],
        "a missing app would land in the Dock as a question mark"
    )
}
