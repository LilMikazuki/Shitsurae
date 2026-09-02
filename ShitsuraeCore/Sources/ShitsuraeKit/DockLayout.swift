import Foundation
import ShitsuraeCore

public struct DockLayout: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var order: Int
    public var name: String
    public var apps: [DockApp]
    public var settings: DockSettings
    public var lastUsedAt: Date?
    public var quitsOtherApps: Bool

    public init(
        id: UUID = UUID(),
        order: Int,
        name: String,
        apps: [DockApp],
        settings: DockSettings,
        lastUsedAt: Date? = nil,
        quitsOtherApps: Bool = false
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.apps = apps
        self.settings = settings
        self.lastUsedAt = lastUsedAt
        self.quitsOtherApps = quitsOtherApps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        order = try container.decode(Int.self, forKey: .order)
        name = try container.decode(String.self, forKey: .name)
        apps = try container.decode([DockApp].self, forKey: .apps)
        settings = try container.decode(DockSettings.self, forKey: .settings)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        quitsOtherApps = try container.decodeIfPresent(Bool.self, forKey: .quitsOtherApps) ?? false
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

    /// A hand-edited file must not hold one tile twice: the Dock does not, and
    /// the strip keys on `DockApp.id`.
    func withUniqueApps() -> DockLayout {
        var seen: Set<String> = []
        var copy = self
        copy.apps = apps.filter { seen.insert($0.id).inserted }
        return copy
    }

    public var dockState: DockState {
        DockState(apps: apps, settings: settings)
    }
}
