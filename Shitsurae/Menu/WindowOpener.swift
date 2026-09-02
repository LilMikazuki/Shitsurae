import AppKit

@MainActor
final class WindowOpener {
    private var open: ((String) -> Void)?

    func register(_ open: @escaping (String) -> Void) {
        self.open = open
    }

    func show(_ id: String) {
        NSApplication.shared.activate()
        open?(id)
    }
}
