import ShitsuraeKit
import SwiftUI

struct MenuBarIcon: View {
    let model: AppModel
    let windows: WindowOpener
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "dock.rectangle")
            // `OpenWindowAction` exists only in a view's environment, and the label is the one
            // view alive for the whole run: the menu's content is built when the menu opens.
            .onAppear {
                windows.register { openWindow(id: $0) }
            }
            .onChange(of: model.alert) { _, alert in
                guard alert != nil else { return }
                ShitsuraeAlert.present(model)
            }
    }
}
