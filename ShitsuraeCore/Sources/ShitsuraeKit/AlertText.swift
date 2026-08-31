import Foundation

public extension ShitsuraeFailure {
    var title: String {
        switch self {
        case .unreadableLayout:
            "Shitsurae can't read your Dock layout"
        case .unsupportedSetting:
            "Shitsurae doesn't recognize one of your Dock settings"
        case .unsupportedTile:
            "Shitsurae can't read Docks with separators"
        case .backupFailed:
            "Shitsurae couldn't back up your current Dock"
        case .writeFailed:
            "Shitsurae couldn't save your Dock settings"
        case .writtenButNotApplied(.restartRefused):
            "Your Dock was changed but not applied"
        case .writtenButNotApplied(.writeIncomplete):
            "Your original Dock was only partly restored"
        case .restoreFailed:
            "Shitsurae can't restore your original Dock"
        }
    }

    var message: String {
        switch self {
        case .unreadableLayout:
            """
            This version of macOS stores it in a format Shitsurae doesn't recognize. \
            Nothing was changed.
            """
        case let .unsupportedSetting(key, value):
            """
            The setting "\(key)" is set to "\(value)", which Shitsurae doesn't \
            understand. Nothing was changed.
            """
        case let .unsupportedTile(tileType):
            """
            Your Dock contains a \(tileType) that Shitsurae doesn't support yet. \
            Nothing was changed.
            """
        case .backupFailed:
            """
            Nothing was changed. Shitsurae won't touch your Dock without a backup \
            it can restore.
            """
        case .writeFailed:
            """
            macOS didn't accept the change. Your Dock may be left part-way — \
            apply the layout again, or restore your original Dock.
            """
        case .writtenButNotApplied(.restartRefused):
            """
            Shitsurae couldn't restart the Dock. Run `killall Dock` in Terminal \
            to finish.
            """
        case .writtenButNotApplied(.writeIncomplete):
            """
            Some settings couldn't be written back, so your Dock has changed. \
            The backup is still on disk — try Restore Original Dock again.
            """
        case .restoreFailed:
            "The backup is missing or unreadable. Nothing was changed."
        }
    }
}

public extension ShitsuraeAlertKind {
    var title: String {
        switch self {
        case .restore: "Restore the Dock to its original state?"
        case .saveFailed: "Shitsurae couldn't save this layout"
        case let .delete(_, name): "Delete layout \"\(name)\"?"
        case let .failure(failure): failure.title
        }
    }

    var message: String {
        switch self {
        case .restore:
            "Current layout will be replaced."
        case .saveFailed:
            "Your Dock was not changed. Check that ~/Library/Application Support is writable."
        case .delete:
            "This can't be undone."
        case let .failure(failure):
            failure.message
        }
    }

    var confirmTitle: String {
        switch self {
        case .restore: "Restore"
        case .saveFailed: "OK"
        case .delete: "Delete"
        case .failure: "OK"
        }
    }

    var hasCancel: Bool {
        switch self {
        case .failure, .saveFailed: false
        case .restore, .delete: true
        }
    }

    var isDestructive: Bool {
        if case .delete = self {
            return true
        }
        return false
    }
}
