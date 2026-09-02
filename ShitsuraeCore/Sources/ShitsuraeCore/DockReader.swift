import Foundation

struct DockReader {
    private let store: DockPreferenceStore

    init(store: DockPreferenceStore) {
        self.store = store
    }

    func read() throws(DockReadError) -> DockState {
        var settings = DockSettings()
        settings.tilesize = try number(DockKey.tilesize)
        settings.largesize = try number(DockKey.largesize)
        settings.magnification = try bool(DockKey.magnification)
        settings.autohide = try bool(DockKey.autohide)
        settings.showRecents = try bool(DockKey.showRecents)
        settings.orientation = try orientation()
        return try DockState(apps: apps(), settings: settings)
    }

    private func number(_ key: String) throws(DockReadError) -> Double? {
        guard let raw = store.value(forKey: key) else { return nil }
        guard !isCFBoolean(raw), let value = raw as? NSNumber else {
            throw DockReadError.wrongType(key: key, expected: "Number")
        }
        return value.doubleValue
    }

    private func bool(_ key: String) throws(DockReadError) -> Bool? {
        guard let raw = store.value(forKey: key) else { return nil }
        guard isCFBoolean(raw), let value = raw as? NSNumber else {
            throw DockReadError.wrongType(key: key, expected: "Bool")
        }
        return value.boolValue
    }

    private func isCFBoolean(_ value: Any) -> Bool {
        CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID()
    }

    private func orientation() throws(DockReadError) -> DockOrientation? {
        guard let raw = store.value(forKey: DockKey.orientation) else { return nil }
        guard let string = raw as? String else {
            throw DockReadError.wrongType(key: DockKey.orientation, expected: "String")
        }
        guard let value = DockOrientation(rawValue: string) else {
            throw DockReadError.unsupportedValue(key: DockKey.orientation, value: string)
        }
        return value
    }

    private func apps() throws(DockReadError) -> [DockApp] {
        guard let raw = store.value(forKey: DockKey.apps) else { return [] }
        guard let rawTiles = raw as? [Any] else {
            throw DockReadError.wrongType(key: DockKey.apps, expected: "Array")
        }
        let tiles: [[String: Any]] = try rawTiles.enumerated()
            .map { index, element throws(DockReadError) in
                guard let tile = element as? [String: Any] else {
                    throw DockReadError.malformedTile(
                        index: index,
                        reason: "tile is not a dictionary"
                    )
                }
                return tile
            }
        return try tiles.enumerated().map { index, tile throws(DockReadError) in
            guard let tileType = tile["tile-type"] as? String else {
                throw DockReadError.malformedTile(index: index, reason: "missing tile-type")
            }
            guard tileType == "file-tile" else {
                throw DockReadError.unsupportedTileType(index: index, tileType: tileType)
            }
            guard let data = tile["tile-data"] as? [String: Any] else {
                throw DockReadError.malformedTile(index: index, reason: "missing tile-data")
            }
            guard let fileData = data["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString),
                  url.isFileURL,
                  !url.path.isEmpty
            else {
                throw DockReadError.malformedTile(index: index, reason: "missing path")
            }
            guard let label = data["file-label"] as? String else {
                throw DockReadError.malformedTile(index: index, reason: "missing file-label")
            }
            guard let bundleId = data["bundle-identifier"] as? String else {
                throw DockReadError.malformedTile(index: index, reason: "missing bundle-identifier")
            }
            return DockApp(path: url.path, bundleId: bundleId, label: label)
        }
    }
}
