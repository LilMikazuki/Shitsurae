import ShitsuraeKit
import SwiftUI

struct MenuBarIcon: View {
    let windows: WindowOpener
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "dock.rectangle")
            // `OpenWindowAction` exists only in a view's environment, and the label is the one
            // view alive for the whole run: the menu's content is built when the menu opens.
            .onAppear {
                windows.register { openWindow(id: $0) }
            }
    }
}
