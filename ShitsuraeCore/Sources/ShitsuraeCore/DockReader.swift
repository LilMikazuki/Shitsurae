import Foundation

/// Домен `com.apple.dock` -> `DockState`.
/// Отсутствие ключа трактуется как значение по умолчанию и даёт `nil`.
/// Неверный тип — ошибка: значит формат сменился и писать нельзя.
public struct DockReader {
    private let store: DockPreferenceStore

    public init(store: DockPreferenceStore) {
        self.store = store
    }

    public func read() throws -> DockState {
        var settings = DockSettings()
        settings.tilesize = try number(DockKey.tilesize)
        settings.largesize = try number(DockKey.largesize)
        settings.magnification = try bool(DockKey.magnification)
        settings.autohide = try bool(DockKey.autohide)
        settings.showRecents = try bool(DockKey.showRecents)
        settings.orientation = try orientation()
        return DockState(apps: try apps(), settings: settings)
    }

    private func number(_ key: String) throws -> Double? {
        guard let raw = store.value(forKey: key) else { return nil }
        guard let value = raw as? NSNumber else {
            throw DockReadError.wrongType(key: key, expected: "Number")
        }
        return value.doubleValue
    }

    private func bool(_ key: String) throws -> Bool? {
        guard let raw = store.value(forKey: key) else { return nil }
        guard let value = raw as? NSNumber else {
            throw DockReadError.wrongType(key: key, expected: "Bool")
        }
        return value.boolValue
    }

    private func orientation() throws -> DockOrientation? {
        guard let raw = store.value(forKey: DockKey.orientation) else { return nil }
        guard let string = raw as? String,
              let value = DockOrientation(rawValue: string) else {
            throw DockReadError.wrongType(key: DockKey.orientation, expected: "left|bottom|right")
        }
        return value
    }

    /// Реализуется в задаче 4. Пока пустой список, чтобы задача 3 собиралась.
    private func apps() throws -> [DockApp] {
        []
    }
}
