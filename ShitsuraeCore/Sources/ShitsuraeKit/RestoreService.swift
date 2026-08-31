import Foundation
import ShitsuraeCore

public final class RestoreService: Sendable {
    private let backup: DockBackup
    private let restarter: DockRestarting
    private let marker: ActiveLayoutMarker

    public init(backup: DockBackup, restarter: DockRestarting, defaults: UserDefaults = .standard) {
        self.backup = backup
        self.restarter = restarter
        marker = ActiveLayoutMarker(defaults: defaults)
    }

    public var canRestore: Bool {
        backup.exists
    }

    public func restore() throws {
        try backup.restore()
        try restarter.restart()
        marker.id = nil
    }
}
