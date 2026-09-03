import AppKit
import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit

final class FakeDockEngine: DockApplying, @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var _stateToReturn = DockState(apps: [], settings: DockSettings())
    private nonisolated(unsafe) var _readError: DockError?
    private nonisolated(unsafe) var _applyError: DockError?
    private nonisolated(unsafe) var _readCount = 0
    private nonisolated(unsafe) var _applied: [DockState] = []

    var stateToReturn: DockState {
        get { lock.withLock { _stateToReturn } }
        set { lock.withLock { _stateToReturn = newValue } }
    }

    var readError: DockError? {
        get { lock.withLock { _readError } }
        set { lock.withLock { _readError = newValue } }
    }

    var applyError: DockError? {
        get { lock.withLock { _applyError } }
        set { lock.withLock { _applyError = newValue } }
    }

    var readCount: Int {
        lock.withLock { _readCount }
    }

    var applied: [DockState] {
        lock.withLock { _applied }
    }

    func read() throws(DockError) -> DockState {
        let thrown: DockError? = lock.withLock {
            _readCount += 1
            return _readError
        }
        if let thrown {
            throw thrown
        }
        return stateToReturn
    }

    func apply(_ state: DockState) throws(DockError) {
        let thrown: DockError? = lock.withLock {
            if let _applyError {
                return _applyError
            }
            _applied.append(state)
            return nil
        }
        if let thrown {
            throw thrown
        }
    }

    @discardableResult
    func applyIfNeeded(_ state: DockState) throws(DockError) -> Bool {
        let current = try read()
        guard state != current else { return false }
        try apply(state)
        return true
    }
}

final class InMemoryUserDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var storage: [String: Any] = [:]

    convenience init() {
        self.init(suiteName: "shitsurae-tests-\(UUID().uuidString)")!
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock { storage[defaultName] = value }
    }

    override func string(forKey defaultName: String) -> String? {
        lock.withLock { storage[defaultName] as? String }
    }

    override func removeObject(forKey defaultName: String) {
        lock.withLock { _ = storage.removeValue(forKey: defaultName) }
    }

    override func object(forKey defaultName: String) -> Any? {
        lock.withLock { storage[defaultName] }
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        lock.withLock { storage[defaultName] = value }
    }

    override func bool(forKey defaultName: String) -> Bool {
        lock.withLock { storage[defaultName] as? Bool ?? false }
    }
}

func temporaryDefaults() -> UserDefaults {
    InMemoryUserDefaults()
}

func testLayout(_ name: String = "Work", order: Int = 0) -> DockLayout {
    var settings = DockSettings()
    settings.autohide = true
    return DockLayout(
        order: order,
        name: name,
        apps: [DockApp(
            path: "/Applications/Safari.app",
            bundleId: "com.apple.Safari",
            label: "Safari"
        )],
        settings: settings
    )
}

final class FakeAppQuitter: AppQuitting, @unchecked Sendable {
    private let lock = NSLock()
    private var running: Set<String>
    private var quittedStorage: Set<String> = []

    var quitted: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return quittedStorage
    }

    init(running: Set<String> = []) {
        self.running = running
    }

    func runningBundleIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    func quit(bundleIds: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        quittedStorage.formUnion(bundleIds)
        running.subtract(bundleIds)
    }
}

@MainActor
final class InMemoryHotkeys: Hotkeys {
    private var shortcuts: [UUID: String] = [:]
    private var handler: ((UUID) -> Void)?
    private(set) var enabled = true

    private func combination(_ event: NSEvent) -> String {
        var parts = ""
        if event.modifierFlags.contains(.control) {
            parts += "⌃"
        }
        if event.modifierFlags.contains(.option) {
            parts += "⌥"
        }
        if event.modifierFlags.contains(.shift) {
            parts += "⇧"
        }
        if event.modifierFlags.contains(.command) {
            parts += "⌘"
        }
        return parts + (event.charactersIgnoringModifiers ?? "").uppercased()
    }

    func label(for id: UUID) -> String? {
        shortcuts[id]
    }

    func describe(_ event: NSEvent) -> String? {
        combination(event)
    }

    func owner(of event: NSEvent, excluding id: UUID, among ids: [UUID]) -> UUID? {
        let candidate = combination(event)
        return ids.first { $0 != id && shortcuts[$0] == candidate }
    }

    @discardableResult
    func assign(_ event: NSEvent, to id: UUID) -> Bool {
        shortcuts[id] = combination(event)
        return true
    }

    func clear(for id: UUID) {
        shortcuts[id] = nil
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    func onTrigger(_ handler: @escaping @MainActor (UUID) -> Void) {
        self.handler = handler
    }

    func register(_: [UUID]) {}

    func fire(_ id: UUID) {
        handler?(id)
    }
}

final class RecordingEventLog: EventLog, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(level: LogLevel, category: LogCategory, message: String)] = []

    func record(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        lock.withLock { entries.append((level, category, message)) }
    }

    var messages: [String] {
        lock.withLock { entries.map(\.message) }
    }

    func messages(_ level: LogLevel, _ category: LogCategory) -> [String] {
        lock.withLock {
            entries.filter { $0.level == level && $0.category == category }.map(\.message)
        }
    }
}
