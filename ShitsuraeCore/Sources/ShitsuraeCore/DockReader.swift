import Foundation

/// Домен `com.apple.dock` -> `DockState`.
/// Отсутствие ключа трактуется как значение по умолчанию и даёт `nil`.
/// Неверный тип — ошибка: значит формат сменился и писать нельзя.
struct DockReader {
    private let store: DockPreferenceStore

    init(store: DockPreferenceStore) {
        self.store = store
    }

    func read() throws -> DockState {
        var settings = DockSettings()
        settings.tilesize = try number(DockKey.tilesize)
        settings.largesize = try number(DockKey.largesize)
        settings.magnification = try bool(DockKey.magnification)
        settings.autohide = try bool(DockKey.autohide)
        settings.showRecents = try bool(DockKey.showRecents)
        settings.orientation = try orientation()
        return try DockState(apps: apps(), settings: settings)
    }

    private func number(_ key: String) throws -> Double? {
        guard let raw = store.value(forKey: key) else { return nil }
        // `CFBoolean` — тоже подкласс `NSNumber` (`__NSCFBoolean`), поэтому
        // одного `as? NSNumber` мало: булево значение под числовым ключом
        // молча превратилось бы в 0.0/1.0. Явно исключаем CFBoolean.
        guard !isCFBoolean(raw), let value = raw as? NSNumber else {
            throw DockReadError.wrongType(key: key, expected: "Number")
        }
        return value.doubleValue
    }

    private func bool(_ key: String) throws -> Bool? {
        guard let raw = store.value(forKey: key) else { return nil }
        // Симметрично: `as? NSNumber` пропустил бы и обычный CFNumber
        // (0 или 1) под булевым ключом. Требуем, чтобы значение и правда
        // было CFBoolean, а не числом, которое лишь похоже на него.
        guard isCFBoolean(raw), let value = raw as? NSNumber else {
            throw DockReadError.wrongType(key: key, expected: "Bool")
        }
        return value.boolValue
    }

    /// `NSNumber` — общий Objective-C мост и для `CFBoolean`, и для
    /// `CFNumber`: приведение `as? NSNumber` их не различает. Различаем
    /// по CF type id — единственный надёжный способ отличить эти два случая.
    private func isCFBoolean(_ value: Any) -> Bool {
        CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID()
    }

    private func orientation() throws -> DockOrientation? {
        guard let raw = store.value(forKey: DockKey.orientation) else { return nil }
        guard let string = raw as? String else {
            throw DockReadError.wrongType(key: DockKey.orientation, expected: "String")
        }
        guard let value = DockOrientation(rawValue: string) else {
            throw DockReadError.unsupportedValue(key: DockKey.orientation, value: string)
        }
        return value
    }

    private func apps() throws -> [DockApp] {
        guard let raw = store.value(forKey: DockKey.apps) else { return [] }
        guard let rawTiles = raw as? [Any] else {
            throw DockReadError.wrongType(key: DockKey.apps, expected: "Array")
        }
        let tiles: [[String: Any]] = try rawTiles.enumerated().map { index, element in
            guard let tile = element as? [String: Any] else {
                throw DockReadError.malformedTile(index: index, reason: "tile is not a dictionary")
            }
            return tile
        }
        return try tiles.enumerated().map { index, tile in
            guard let tileType = tile["tile-type"] as? String else {
                throw DockReadError.malformedTile(index: index, reason: "missing tile-type")
            }
            // Dock lets users place spacer tiles directly in `persistent-apps`
            // (`spacer-tile`, `small-spacer-tile`, `flex-spacer-tile`). That's a
            // real, current Dock feature, not format corruption — but we don't
            // parse or round-trip it yet, so fail with a message that names
            // what's actually there instead of claiming a path is missing.
            guard tileType == "file-tile" else {
                throw DockReadError.unsupportedTileType(index: index, tileType: tileType)
            }
            guard let data = tile["tile-data"] as? [String: Any] else {
                throw DockReadError.malformedTile(index: index, reason: "missing tile-data")
            }
            // Путь лежит percent-кодированной URL-строкой; `URL.path` снимает кодирование.
            // Схему проверяем явно: у `http://evil.example/Applications/X.app/`
            // тоже есть правдоподобный `path`, и мы записали бы его обратно
            // локальным file-URL. Молча переосмысливать чужой ввод нельзя.
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
