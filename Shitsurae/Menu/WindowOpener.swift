import AppKit

@MainActor
final class WindowOpener {
    private var open: ((String) -> Void)?

    func register(_ open: @escaping (String) -> Void) {
        self.open = open
    }

    func show(_ id: String) {
        // `activate()` alone is cooperative and documented not to guarantee activation. Measured
        // from the status-item menu: it left the app behind often enough to look like the item
        // needed two or three clicks, while this form activated on all eight tries. The window
        // itself is already open — only the activation was ever missing.
        NSApplication.shared.activate(ignoringOtherApps: true)
        open?(id)
    }
}
