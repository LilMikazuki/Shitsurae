import Foundation

/// Единственный способ, которым Shitsurae общается с доменом настроек.
/// Существует ради тестируемости: боевой стор ходит в `cfprefsd`,
/// а тестовый работает на словаре, снятом с живой системы.
protocol DockPreferenceStore: AnyObject, Sendable {
    func value(forKey key: String) -> Any?
    func setValue(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

/// Боевая реализация поверх CFPreferences.
/// Через CFPreferences, а не правкой plist-файла: иначе `cfprefsd`
/// перезапишет наши изменения содержимым своего кеша.
final class CFPreferencesDockStore: DockPreferenceStore {
    private var domain: CFString {
        DockKey.domain as CFString
    }

    init() {}

    func value(forKey key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain)
    }

    func setValue(_ value: Any?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain)
    }

    @discardableResult func synchronize() -> Bool {
        CFPreferencesAppSynchronize(domain)
    }
}

/// Стор на словаре. Используется тестами и режимом `--dry-run` в CLI.
final class InMemoryDockStore: DockPreferenceStore {
    private let lock = NSLock()
    /// Безопасность поля держит `lock`, а не компилятор. `Mutex` здесь не
    /// подходит: словарь с `Any` не пересекает границу `sending`, и никакая
    /// формулировка сеттера этого не чинит — проверено.
    private nonisolated(unsafe) var storage: [String: Any]

    init(_ storage: [String: Any]) {
        self.storage = storage
    }

    var snapshot: [String: Any] {
        lock.withLock { storage }
    }

    func value(forKey key: String) -> Any? {
        lock.withLock { storage[key] }
    }

    func setValue(_ value: Any?, forKey key: String) {
        // Присваивание, а не `if let` с `removeValue`: словарь сам удаляет ключ
        // при `nil` — на это поведение есть тест, — и присваивание возвращает
        // Void, поэтому `withLock` не даёт предупреждения о неиспользованном
        // результате, как даёт вариант с `removeValue`.
        lock.withLock { storage[key] = value }
    }

    @discardableResult func synchronize() -> Bool { true }
}
