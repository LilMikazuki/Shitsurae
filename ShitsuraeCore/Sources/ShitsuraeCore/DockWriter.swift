import Foundation

/// `DockState` -> домен `com.apple.dock`.
/// Пишет только те ключи, значения которых есть: `nil` означает,
/// что ключа в домене не было и добавлять его мы не имеем права.
public struct DockWriter {
    private let store: DockPreferenceStore

    public init(store: DockPreferenceStore) {
        self.store = store
    }

    public func write(_ state: DockState) {
        store.setValue(state.apps.map(Self.tile(for:)), forKey: DockKey.apps)
        set(state.settings.tilesize, DockKey.tilesize)
        set(state.settings.largesize, DockKey.largesize)
        set(state.settings.magnification, DockKey.magnification)
        set(state.settings.autohide, DockKey.autohide)
        set(state.settings.showRecents, DockKey.showRecents)
        set(state.settings.orientation?.rawValue, DockKey.orientation)
        store.synchronize()
    }

    /// Минимальный тайл. `book`, `GUID`, `dock-extra` и прочее Dock достроит сам
    /// при первом же сохранении — они машинно-зависимые и переносу не подлежат.
    public static func tile(for app: DockApp) -> [String: Any] {
        let url = URL(fileURLWithPath: app.path, isDirectory: true)
        return [
            "tile-type": "file-tile",
            "tile-data": [
                "file-data": [
                    "_CFURLString": url.absoluteString,
                    "_CFURLStringType": 15,
                ],
                "file-label": app.label,
                "bundle-identifier": app.bundleId,
            ] as [String: Any],
        ]
    }

    private func set(_ value: Any?, _ key: String) {
        guard let value else { return }
        store.setValue(value, forKey: key)
    }
}
