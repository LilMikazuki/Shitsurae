import Foundation

/// `DockState` -> домен `com.apple.dock`.
/// Пишет только те ключи, значения которых есть: `nil` означает,
/// что ключа в домене не было и добавлять его мы не имеем права.
struct DockWriter {
    private let store: DockPreferenceStore

    init(store: DockPreferenceStore) {
        self.store = store
    }

    func write(_ state: DockState) throws {
        store.setValue(state.apps.map(Self.tile(for:)), forKey: DockKey.apps)
        set(state.settings.tilesize, DockKey.tilesize)
        set(state.settings.largesize, DockKey.largesize)
        set(state.settings.magnification, DockKey.magnification)
        set(state.settings.autohide, DockKey.autohide)
        set(state.settings.showRecents, DockKey.showRecents)
        set(state.settings.orientation?.rawValue, DockKey.orientation)
        // Результат синхронизации — единственное, что вообще сообщает
        // об успехе записи. Проглотить его значило бы отчитаться об успехе
        // и перезапустить Dock после того, как ничего не сохранилось.
        guard store.synchronize() else {
            throw DockWriteError.synchronizeFailed
        }
    }

    /// Минимальный тайл. `book`, `GUID`, `dock-extra` и прочее Dock достроит сам
    /// при первом же сохранении — они машинно-зависимые и переносу не подлежат.
    static func tile(for app: DockApp) -> [String: Any] {
        let url = URL(fileURLWithPath: app.path, isDirectory: true)
        return [
            "tile-type": "file-tile",
            "tile-data": [
                "file-data": [
                    "_CFURLString": url.absoluteString,
                    "_CFURLStringType": 15
                ],
                "file-label": app.label,
                "bundle-identifier": app.bundleId
            ] as [String: Any]
        ]
    }

    private func set(_ value: Any?, _ key: String) {
        guard let value else { return }
        store.setValue(value, forKey: key)
    }
}
