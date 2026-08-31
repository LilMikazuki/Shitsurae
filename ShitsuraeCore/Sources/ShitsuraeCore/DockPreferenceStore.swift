import Foundation

protocol DockPreferenceStore: AnyObject, Sendable {
    func value(forKey key: String) -> Any?
    func setValue(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

final class CFPreferencesDockStore: DockPreferenceStore {
    private let domain: String

    init(domain: String = DockKey.domain) {
        self.domain = domain
    }

    func value(forKey key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    func setValue(_ value: Any?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain as CFString)
    }

    @discardableResult func synchronize() -> Bool {
        CFPreferencesAppSynchronize(domain as CFString)
    }
}

final class InMemoryDockStore: DockPreferenceStore {
    private let lock = NSLock()
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
        lock.withLock { storage[key] = value }
    }

    @discardableResult func synchronize() -> Bool {
        true
    }
}
