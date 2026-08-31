import Foundation
import ShitsuraeCore

public struct DockLayout: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var order: Int
    public var name: String
    public var apps: [DockApp]
    public var settings: DockSettings
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        order: Int,
        name: String,
        apps: [DockApp],
        settings: DockSettings,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.apps = apps
        self.settings = settings
        self.lastUsedAt = lastUsedAt
    }

    public init(id: UUID = UUID(), order: Int, name: String, state: DockState) {
        self.init(id: id, order: order, name: name, apps: state.apps, settings: state.settings)
    }

    /// Tiles whose application is gone would come back as question marks,
    /// which is why the strip promises to skip them.
    public func dockState(skippingMissing manager: FileManager = .default) -> DockState {
        DockState(
            apps: apps.filter { manager.fileExists(atPath: $0.path) },
            settings: settings
        )
    }

    /// The strip identifies tiles by bundle id and the Dock holds an
    /// application once, so a hand-edited file must not smuggle in a twin.
    func withUniqueApps() -> DockLayout {
        var seen: Set<String> = []
        var copy = self
        copy.apps = apps.filter { seen.insert($0.bundleId).inserted }
        return copy
    }

    public var dockState: DockState {
        DockState(apps: apps, settings: settings)
    }
}
