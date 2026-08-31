import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func layout(appCount: Int) -> DockLayout {
    let apps = (0 ..< appCount).map {
        DockApp(path: "/Applications/App\($0).app", bundleId: "test.\($0)", label: "App\($0)")
    }
    return DockLayout(order: 0, name: "Work", apps: apps, settings: DockSettings())
}

@Test func oneAppIsCountedInTheSingular() {
    #expect(LayoutSummary.appCount(layout(appCount: 1)) == "1 app")
    #expect(LayoutSummary.appCount(layout(appCount: 2)) == "2 apps")
    #expect(LayoutSummary.appCount(layout(appCount: 0)) == "0 apps")
}
