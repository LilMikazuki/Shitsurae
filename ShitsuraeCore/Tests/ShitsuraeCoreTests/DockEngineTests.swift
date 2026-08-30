import Foundation
@testable import ShitsuraeCore
import Testing

private final class FakeRestarter: DockRestarting {
    private let lock = NSLock()
    private nonisolated(unsafe) var _restarts = 0
    private nonisolated(unsafe) var _errorToThrow: DockRestartError?

    var restarts: Int { lock.withLock { _restarts } }

    var errorToThrow: DockRestartError? {
        get { lock.withLock { _errorToThrow } }
        set { lock.withLock { _errorToThrow = newValue } }
    }

    func restart() throws {
        lock.withLock { _restarts += 1 }
        if let error = errorToThrow { throw error }
    }
}

/// Стор, который принимает запись, но честно сообщает, что синхронизация
/// провалилась, — так ведёт себя `CFPreferencesAppSynchronize`, когда
/// `cfprefsd` не принял изменения.
private final class NonSynchronizingStore: DockPreferenceStore {
    private let inner: InMemoryDockStore

    init(_ inner: InMemoryDockStore) {
        self.inner = inner
    }

    func value(forKey key: String) -> Any? {
        inner.value(forKey: key)
    }

    func setValue(_ value: Any?, forKey key: String) {
        inner.setValue(value, forKey: key)
    }

    @discardableResult func synchronize() -> Bool {
        false
    }
}

private func временнаяПапка() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-engine-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func применениеПишетДелаетБэкапИПерезапускает() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try fixtureStore()
    let backup = DockBackup(directory: dir)
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: backup, restarter: restarter)

    var target = try engine.read()
    target.apps = [DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )]
    try engine.apply(target)

    #expect(try engine.read().apps.count == 1)
    #expect(backup.exists == true)
    #expect(restarter.restarts == 1)
}

@Test func нечитаемыйДоменЗапрещаетЗапись() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    // Домен, который мы не умеем разбирать: tilesize строкой.
    let store = InMemoryDockStore([DockKey.tilesize: "большой"])
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: DockBackup(directory: dir), restarter: restarter)

    #expect(throws: DockReadError.self) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    // Ничего не записано и Dock не тронут.
    #expect(store.value(forKey: DockKey.apps) == nil)
    #expect(restarter.restarts == 0)
    #expect(DockBackup(directory: dir).exists == false)
}

@Test func повторноеПрименениеНеДелаетВторойБэкап() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let engine = try DockEngine(
        store: fixtureStore(),
        backup: DockBackup(directory: dir),
        restarter: FakeRestarter()
    )
    let state = try engine.read()
    try engine.apply(state)
    let first = try Data(contentsOf: DockBackup(directory: dir).backupURL)
    try engine.apply(state)
    #expect(try Data(contentsOf: DockBackup(directory: dir).backupURL) == first)
}

/// Провал синхронизации означает, что записанное не сохранилось. Перезапускать
/// Dock после этого нельзя: панель моргнула бы, сделав вид, что пресет применён.
@Test func провалСинхронизацииОтменяетПерезапуск() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try NonSynchronizingStore(fixtureStore())
    let restarter = FakeRestarter()
    let engine = DockEngine(store: store, backup: DockBackup(directory: dir), restarter: restarter)

    #expect(throws: DockWriteError.synchronizeFailed) {
        try engine.apply(DockState(apps: [], settings: DockSettings()))
    }
    #expect(restarter.restarts == 0)
}

@Test func ошибкаПерезапускаНеГлотаетсяНоЗаписьИБэкапУжеСделаны() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = try fixtureStore()
    let backup = DockBackup(directory: dir)
    let restarter = FakeRestarter()
    restarter.errorToThrow = .dockProcessNotFound
    let engine = DockEngine(store: store, backup: backup, restarter: restarter)

    var target = try engine.read()
    target.apps = [DockApp(
        path: "/Applications/Safari.app",
        bundleId: "com.apple.Safari",
        label: "Safari"
    )]

    #expect(throws: DockRestartError.self) {
        try engine.apply(target)
    }

    // Ошибка перезапуска не должна прятать то, что уже случилось:
    // запись и бэкап сделаны, применить не удалось — но не потеряно.
    #expect(try engine.read().apps.count == 1)
    #expect(backup.exists == true)
}

/// `restarts` считает попытки, а не успехи: провалившийся перезапуск —
/// это всё равно предпринятый перезапуск, и тест на путь «записано,
/// но не применено» опирается на то, что попытка была.
@Test func счётчикРестартовСчитаетПопыткиАНеУспехи() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let restarter = FakeRestarter()
    restarter.errorToThrow = .dockProcessNotFound
    let engine = DockEngine(
        store: try fixtureStore(),
        backup: DockBackup(directory: dir),
        restarter: restarter)

    #expect(throws: DockRestartError.dockProcessNotFound) {
        try engine.apply(try engine.read())
    }
    #expect(restarter.restarts == 1)
}
