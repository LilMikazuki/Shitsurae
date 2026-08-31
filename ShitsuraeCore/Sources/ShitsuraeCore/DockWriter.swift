import Foundation

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
        guard store.synchronize() else {
            throw DockWriteError.synchronizeFailed
        }
    }

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

    private func set(_ value: (some Any)?, _ key: String) {
        // A layout without the setting must clear it: otherwise the previous
        // layout's orientation or magnification sticks to every later one.
        store.setValue(value, forKey: key)
    }
}
