import ShitsuraeKit
import SwiftUI

@MainActor
final class WindowOpener {
    static let shared = WindowOpener()

    private var open: ((String) -> Void)?

    private init() {}

    func register(_ open: @escaping (String) -> Void) {
        self.open = open
    }

    func show(_ id: String) {
        NSApplication.shared.activate()
        open?(id)
    }
}

struct MenuBarIcon: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "dock.rectangle")
            .onAppear {
                WindowOpener.shared.register { openWindow(id: $0) }
            }
            .onChange(of: model.alert) { _, alert in
                guard alert != nil else { return }
                ShitsuraeAlert.present(model)
            }
    }
}
