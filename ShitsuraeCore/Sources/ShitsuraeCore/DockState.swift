import Foundation

/// Положение Dock на экране. Значения — те же строки, что лежат в домене.
public enum DockOrientation: String, Codable, Sendable, CaseIterable {
    case left, bottom, right
}

/// Одно приложение из левой части Dock.
/// `book`, `GUID` и прочие поля тайла сюда не переносятся: они привязаны
/// к конкретной машине, а пресеты должны быть переносимыми.
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

/// Настройки Dock. Все поля опциональны: отсутствие ключа в домене — норма,
/// это значение по умолчанию, и записывать его обратно мы не имеем права.
public struct DockSettings: Equatable, Codable, Sendable {
    public var tilesize: Double?
    public var magnification: Bool?
    public var largesize: Double?
    public var autohide: Bool?
    public var orientation: DockOrientation?
    public var showRecents: Bool?

    public init() {}
}

/// Полный снимок того, что Shitsurae умеет читать и писать.
public struct DockState: Equatable, Sendable {
    public var apps: [DockApp]
    public var settings: DockSettings

    public init(apps: [DockApp], settings: DockSettings) {
        self.apps = apps
        self.settings = settings
    }
}
