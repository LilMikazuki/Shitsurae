import Foundation

public enum DockOrientation: String, Codable, Sendable, CaseIterable {
    case left, bottom, right
}

public struct DockApp: Equatable, Codable, Sendable {
    public var path: String
    public var bundleId: String
    public var label: String

    public init(path: String, bundleId: String, label: String) {
        self.path = path
        self.bundleId = bundleId
        self.label = label
    }
}

public struct DockSettings: Equatable, Codable, Sendable {
    public var tilesize: Double?
    public var magnification: Bool?
    public var largesize: Double?
    public var autohide: Bool?
    public var orientation: DockOrientation?
    public var showRecents: Bool?

    public init() {}
}

public struct DockState: Equatable, Codable, Sendable {
    public var apps: [DockApp]
    public var settings: DockSettings

    public init(apps: [DockApp], settings: DockSettings) {
        self.apps = apps
        self.settings = settings
    }
}
