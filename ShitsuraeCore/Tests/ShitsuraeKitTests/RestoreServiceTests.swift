import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-restore-svc-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func randomDomain() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-domain-\(UUID().uuidString).plist").path
}

private func writeToDomain(_ domain: String, key: String, value: String) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["write", domain, key, value]
    try p.run()
    p.waitUntilExit()
}

private func removeDomain(_ domain: String) {
    try? FileManager.default.removeItem(atPath: domain)
}

@Test func restoreIsRefusedWithoutABackup() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let service = RestoreService(
        backup: DockBackup(directory: dir, domain: randomDomain()),
        restarter: FakeRestarter(),
        defaults: temporaryDefaults()
    )
    #expect(service.canRestore == false)
}

@Test func restoreWithoutABackupThrowsAndLeavesTheDockAlone() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let restarter = FakeRestarter()
    let service = RestoreService(
        backup: DockBackup(directory: dir, domain: randomDomain()),
        restarter: restarter,
        defaults: temporaryDefaults()
    )

    #expect(throws: DockBackupError.backupMissing) {
        try service.restore()
    }
    #expect(restarter.restartCount == 0)
}

@Test func restoreClearsTheActiveLayout() throws {
    let defaults = temporaryDefaults()
    let switcher = SwitchService(engine: FakeDockEngine(), defaults: defaults)
    try switcher.apply(testLayout())
    #expect(switcher.lastAppliedLayoutID != nil)

    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }
    let domain = randomDomain()
    defer { removeDomain(domain) }
    try writeToDomain(domain, key: "marker", value: "original")

    let backup = DockBackup(directory: dir, domain: domain)
    try backup.createIfNeeded()
    let service = RestoreService(backup: backup, restarter: FakeRestarter(), defaults: defaults)

    try service.restore()

    #expect(SwitchService(engine: FakeDockEngine(), defaults: defaults).lastAppliedLayoutID == nil)
}
