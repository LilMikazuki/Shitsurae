import Foundation

/// Единственный способ, которым Shitsurae общается с доменом настроек.
/// Существует ради тестируемости: боевой стор ходит в `cfprefsd`,
/// а тестовый работает на словаре, снятом с живой системы.
public protocol DockPreferenceStore: AnyObject, Sendable {
    func value(forKey key: String) -> Any?
    func setValue(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

/// Боевая реализация поверх CFPreferences.
/// Через CFPreferences, а не правкой plist-файла: иначе `cfprefsd`
/// перезапишет наши изменения содержимым своего кеша.
public final class CFPreferencesDockStore: DockPreferenceStore {
    /// Строкой, а не `static let ... as CFString`: `CFString` не `Sendable`,
    /// и Swift 6 отвергает такой глобальный литерал.
    public static let domainName = "com.apple.dock"

    private var domain: CFString {
        Self.domainName as CFString
    }

    public init() {}

    public func value(forKey key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain)
    }

    public func setValue(_ value: Any?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain)
    }

    @discardableResult public func synchronize() -> Bool {
        CFPreferencesAppSynchronize(domain)
    }
}

/// Стор на словаре. Используется тестами и режимом `--dry-run` в CLI.
public final class InMemoryDockStore: DockPreferenceStore {
    private let lock = NSLock()
    /// Безопасность поля держит `lock`, а не компилятор. `Mutex` здесь не
    /// подходит: словарь с `Any` не пересекает границу `sending`, и никакая
    /// формулировка сеттера этого не чинит — проверено.
    private nonisolated(unsafe) var storage: [String: Any]

    public init(_ storage: [String: Any]) {
        self.storage = storage
    }

    public var snapshot: [String: Any] {
        lock.withLock { storage }
    }

    public func value(forKey key: String) -> Any? {
        lock.withLock { storage[key] }
    }

    public func setValue(_ value: Any?, forKey key: String) {
        // Присваивание, а не `if let` с `removeValue`: словарь сам удаляет ключ
        // при `nil` — на это поведение есть тест, — и присваивание возвращает
        // Void, поэтому `withLock` не даёт предупреждения о неиспользованном
        // результате, как даёт вариант с `removeValue`.
        lock.withLock { storage[key] = value }
    }

    @discardableResult public func synchronize() -> Bool { true }
}
