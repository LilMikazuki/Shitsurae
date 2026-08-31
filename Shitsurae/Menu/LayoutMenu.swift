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
                Button {
                    Task {
                        await model.apply(id: layout.id)
                    }
                } label: {
                    if let hotkey = model.shortcuts.label(for: layout.id) {
                        menuLabel(layout, trailing: hotkey)
                    } else {
                        menuLabel(layout, trailing: nil)
                    }
                }
            }
        }

        Divider()

        Button("Save Current Dock as Layout…") {
            activateAndOpen("save-layout")
        }

        Button("Restore Original Dock") {
            model.askRestore()
        }
        .disabled(!model.canRestore || model.isChangingDock)

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

    @ViewBuilder
    private func menuLabel(_ layout: DockLayout, trailing: String?) -> some View {
        let name = trailing.map { "\(layout.name)   \($0)" } ?? layout.name
        Label {
            Text(name)
        } icon: {
            Image(systemName: "checkmark")
                .opacity(layout.id == model.activeLayoutID ? 1 : 0)
        }
    }

    private func activateAndOpen(_ id: String) {
        NSApplication.shared.activate()
        openWindow(id: id)
    }
}
