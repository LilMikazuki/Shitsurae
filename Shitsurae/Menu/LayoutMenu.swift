import ShitsuraeKit
import SwiftUI

struct LayoutMenu: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.layouts.isEmpty {
            Text("No layouts yet — save your current Dock to start")
                .disabled(true)
        } else {
            ForEach(model.layouts) { layout in
                Toggle(isOn: applied(layout)) {
                    Text(title(layout))
                }
            }
        }

        Divider()

        Button("Save Current Dock as Layout…") {
            activateAndOpen("save-layout")
        }

        Divider()

        Button("Settings…") {
            WindowOpener.shared.show("settings")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Shitsurae") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func applied(_ layout: DockLayout) -> Binding<Bool> {
        Binding(
            get: { layout.id == model.activeLayoutID },
            set: { _ in
                Task {
                    await model.apply(id: layout.id)
                }
            }
        )
    }

    private func title(_ layout: DockLayout) -> String {
        guard let hotkey = model.shortcuts.label(for: layout.id) else { return layout.name }
        return "\(layout.name)   \(hotkey)"
    }

    private func activateAndOpen(_ id: String) {
        NSApplication.shared.activate()
        openWindow(id: id)
    }
}
