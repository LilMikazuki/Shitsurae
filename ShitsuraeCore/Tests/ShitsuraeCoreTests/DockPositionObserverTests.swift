import Foundation
@testable import ShitsuraeCore
import Testing

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private func scratchDomain() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-observer-\(UUID().uuidString).plist").path
}

private func write(_ value: String, forKey key: String, in domain: String) {
    CFPreferencesSetAppValue(key as CFString, value as CFString, domain as CFString)
    CFPreferencesAppSynchronize(domain as CFString)
}

@Test func theObserverReportsAChangeOfTheDocksPosition() throws {
    let domain = scratchDomain()
    defer { try? FileManager.default.removeItem(atPath: domain) }
    let changes = Counter()
    let created = DockPositionObserver(domain: domain) { changes.increment() }
    let observer = try #require(created)

    write("left", forKey: DockKey.orientation, in: domain)
    write("right", forKey: DockKey.orientation, in: domain)

    #expect(changes.value == 2)
    withExtendedLifetime(observer) {}
}

@Test func theObserverStaysSilentWhenAnotherDockSettingChanges() throws {
    let domain = scratchDomain()
    defer { try? FileManager.default.removeItem(atPath: domain) }
    let changes = Counter()
    let created = DockPositionObserver(domain: domain) { changes.increment() }
    let observer = try #require(created)

    write("48", forKey: DockKey.tilesize, in: domain)
    write("64", forKey: DockKey.tilesize, in: domain)
    write("left", forKey: DockKey.orientation, in: domain)

    #expect(changes.value == 1)
    withExtendedLifetime(observer) {}
}
