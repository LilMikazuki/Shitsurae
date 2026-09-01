import ShitsuraeCore
import ShitsuraeKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(
        _: NSApplication,
        hasVisibleWindows visible: Bool
    ) -> Bool {
        guard !visible else { return true }
        WindowOpener.shared.show("settings")
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}

@main
struct ShitsuraeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel

    init() {
        LayoutStore.migrateLegacyDirectory()
        let engine = DockEngine.live()
        let switcher = SwitchService(engine: engine)
        let restorer = RestoreService(
            backup: DockBackup(directory: DockBackup.defaultDirectory),
            restarter: DockRestarter()
        )
        let model = AppModel(
            store: LayoutStore(directory: LayoutStore.defaultDirectory),
            switcher: switcher,
            restorer: restorer
        )
        model.reload()
        model.seedInitialLayoutIfNeeded()
        model.shortcuts.onTrigger { [weak model] id in
            Task { await model?.apply(id: id) }
        }
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            LayoutMenu(model: model)
        } label: {
            MenuBarIcon(model: model)
        }
        .menuBarExtraStyle(.menu)

        Window("Save Current Dock as Layout", id: "save-layout") {
            SaveLayoutView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // A plain window rather than the `Settings` scene: `SettingsLink` inside
        // `MenuBarExtra` never creates a window at all.
        Window("Shitsurae Settings", id: "settings") {
            SettingsWindow(model: model, launchAtLogin: SMAppServiceLaunchAtLogin())
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 940, height: 620)
        .defaultPosition(.center)
    }
}
