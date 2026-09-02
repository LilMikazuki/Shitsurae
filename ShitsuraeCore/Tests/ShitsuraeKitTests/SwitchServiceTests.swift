import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

@Test func applyingHandsTheEngineTheLayoutState() throws {
    let engine = FakeDockEngine()
    let service = SwitchService(engine: engine)
    let layout = testLayout()

    try service.apply(layout)

    #expect(engine.applied == [layout.dockState])
}

@Test func applyingSkipsApplicationsThatAreGoneFromDisk() throws {
    let engine = FakeDockEngine()
    let service = SwitchService(engine: engine)
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
