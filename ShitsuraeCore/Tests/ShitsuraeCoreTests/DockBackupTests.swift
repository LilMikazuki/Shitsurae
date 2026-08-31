import Foundation
@testable import ShitsuraeCore
import Testing

private func populatedDomain() throws -> String {
    let domain = temporaryDomain()
    try writeToDomain(domain, key: DockKey.apps, value: "marker")
    return domain
}

private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func theBackupIsCreatedAndIsAValidPlist() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = try DockBackup(directory: dir, domain: populatedDomain())
    #expect(backup.exists == false)
    #expect(try backup.createIfNeeded() == true)
    #expect(backup.exists == true)

    let data = try Data(contentsOf: backup.backupURL)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    let dict = try #require(plist as? [String: Any])
    #expect(dict[DockKey.apps] != nil)
}

@Test func aSecondBackupDoesNotOverwriteTheFirst() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = try DockBackup(directory: dir, domain: populatedDomain())
    #expect(try backup.createIfNeeded() == true)
    let first = try Data(contentsOf: backup.backupURL)

    #expect(try backup.createIfNeeded() == false)
    #expect(try Data(contentsOf: backup.backupURL) == first)
}

@Test func theDefaultPathIsInApplicationSupport() {
    let path = DockBackup.defaultDirectory.path
    #expect(path.hasSuffix("Library/Application Support/Shitsurae/backup"))
}

@Test func exportingToAnUnwritableDirectoryThrowsInsteadOfReturningTrue() throws {
    let dir = try temporaryFolder()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: dir)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)

    let backup = try DockBackup(directory: dir, domain: populatedDomain())
    #expect(throws: DockBackupError.self) {
        try backup.createIfNeeded()
    }
}

@Test func aZeroByteFileDoesNotCountAsAnExistingBackup() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = try DockBackup(directory: dir, domain: populatedDomain())
    FileManager.default.createFile(atPath: backup.backupURL.path, contents: Data())

    #expect(backup.exists == false)
    #expect(try backup.createIfNeeded() == true)
    #expect(backup.exists == true)

    let data = try Data(contentsOf: backup.backupURL)
    #expect(!data.isEmpty)
}

private func temporaryDomain() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-domain-\(UUID().uuidString).plist").path
}

private func removeDomain(_ domain: String) {
    try? FileManager.default.removeItem(atPath: domain)
}

private func writeToDomain(_ domain: String, key: String, value: String) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["write", domain, key, value]
    try p.run()
    p.waitUntilExit()
}

private func readFromDomain(_ domain: String, key: String) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["read", domain, key]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    try? p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

@Test func restoreWithoutABackupThrowsAClearError() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = try DockBackup(directory: dir, domain: populatedDomain())
    #expect(throws: DockBackupError.backupMissing) { try backup.restore() }
}

@Test func restoreReturnsTheDomainToTheBackupState() throws {
    let domain = temporaryDomain()
    defer { removeDomain(domain) }
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: domain)
    try writeToDomain(domain, key: "marker", value: "original")
    #expect(try backup.createIfNeeded())

    try writeToDomain(domain, key: "marker", value: "changed")
    #expect(readFromDomain(domain, key: "marker") == "changed")

    try backup.restore()
    #expect(readFromDomain(domain, key: "marker") == "original")
}

@Test func aCorruptBackupFileDoesNotCountAsABackup() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = try DockBackup(directory: dir, domain: populatedDomain())
    try Data("not a plist".utf8).write(to: backup.backupURL)

    #expect(backup.exists == false)
    #expect(throws: DockBackupError.backupMissing) { try backup.restore() }
}

@Test func restoreDoesNotDeleteTheBackup() throws {
    let domain = temporaryDomain()
    defer { removeDomain(domain) }
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: domain)
    try writeToDomain(domain, key: "marker", value: "original")
    try backup.createIfNeeded()
    try backup.restore()

    #expect(backup.exists)
}

@Test func theBackupFileNameSurvivesAPathLikeDomain() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: "/tmp/some/where.plist")

    #expect(
        backup.backupURL.deletingLastPathComponent().standardizedFileURL
            == dir.standardizedFileURL,
        "the backup name must stay a single path component"
    )
    #expect(
        DockBackup(directory: dir, domain: "com.apple.dock").backupURL.lastPathComponent
            == "com.apple.dock.original.plist",
        "an existing backup must keep its name"
    )
}

/// A reverse-DNS domain, because `defaults import` and `CFPreferences` only
/// agree on one of those — a plist-path domain cannot express this at all.
/// One fixed name, so a run leaves at most one stray domain rather than one per
/// execution; only this test uses it, so parallel tests cannot collide.
private let restoreTestDomain = "io.github.lilmikazuki.shitsurae.restore-test"

private func forgetDomain(_ domain: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    process.arguments = ["delete", domain]
    try? process.run()
    process.waitUntilExit()
    let plist = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/\(domain).plist")
    try? FileManager.default.removeItem(at: plist)
}

@Test func restoreRemovesASettingTheBackupNeverHad() throws {
    let dir = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: dir) }
    let domain = restoreTestDomain
    forgetDomain(domain)
    defer { forgetDomain(domain) }

    try writeToDomain(domain, key: DockKey.tilesize, value: "48")
    let backup = DockBackup(directory: dir, domain: domain)
    #expect(try backup.createIfNeeded())

    try writeToDomain(domain, key: DockKey.magnification, value: "1")
    #expect(readFromDomain(domain, key: DockKey.magnification) != nil)

    try backup.restore()

    #expect(
        readFromDomain(domain, key: DockKey.magnification) == nil,
        "`defaults import` merges, so a setting added after the backup has to be cleared"
    )
    #expect(readFromDomain(domain, key: DockKey.tilesize) == "48")
}

@Test func anUnwritableBackupFolderIsReportedAsABackupProblem() throws {
    let parent = try temporaryFolder()
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: parent.path
        )
        try? FileManager.default.removeItem(at: parent)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent.path)

    let backup = try DockBackup(
        directory: parent.appendingPathComponent("backup"),
        domain: populatedDomain()
    )

    #expect(throws: DockBackupError.backupDirectoryUnavailable) {
        try backup.createIfNeeded()
    }
}
