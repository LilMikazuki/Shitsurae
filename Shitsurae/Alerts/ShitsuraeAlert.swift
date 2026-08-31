import AppKit
import ShitsuraeKit

enum ShitsuraeAlert {
    @MainActor
    static func present(_ model: AppModel) {
        guard let kind = model.alert else { return }

        let alert = NSAlert()
        alert.messageText = kind.title
        alert.informativeText = kind.message
        alert.alertStyle = kind.hasCancel ? .warning : .informational

        alert.addButton(withTitle: kind.confirmTitle)
        if kind.hasCancel {
            alert.addButton(withTitle: "Cancel")
        }
        if kind.isDestructive {
            alert.buttons.first?.hasDestructiveAction = true
        }

        NSApplication.shared.activate()

        if alert.runModal() == .alertFirstButtonReturn {
            Task { await model.confirmAlert() }
        } else {
            model.dismissAlert()
        }
    }
}
