import ShitsuraeCore
import ShitsuraeKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windows = WindowOpener()

    func applicationShouldHandleReopen(
        _: NSApplication,
        hasVisibleWindows visible: Bool
    ) -> Bool {
        guard !visible else { return true }
        windows.show("settings")
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
        let store = LayoutStore(directory: LayoutStore.defaultDirectory)
        store.adoptStrayFiles()
        let engine = DockEngine.live()
        let switcher = SwitchService(engine: engine)
        let model = AppModel(store: store, switcher: switcher)
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
            MenuBarIcon(model: model, windows: delegate.windows)
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
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 716, height: 486)
        .defaultPosition(.center)
    }
}
