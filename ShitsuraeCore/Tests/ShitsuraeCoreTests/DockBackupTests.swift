import Foundation
@testable import ShitsuraeCore
import Testing

private func временнаяПапка() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("shitsurae-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func бэкапСоздаётсяИЭтоВалидныйPlist() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir)
    #expect(backup.exists == false)
    #expect(try backup.createIfNeeded() == true)
    #expect(backup.exists == true)

    let data = try Data(contentsOf: backup.backupURL)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    let dict = try #require(plist as? [String: Any])
    #expect(dict[DockKey.apps] != nil)
}

@Test func повторныйБэкапНеПерезаписываетПервый() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir)
    #expect(try backup.createIfNeeded() == true)
    let first = try Data(contentsOf: backup.backupURL)

    #expect(try backup.createIfNeeded() == false)
    #expect(try Data(contentsOf: backup.backupURL) == first)
}

@Test func путьПоУмолчаниюВApplicationSupport() {
    let path = DockBackup.defaultDirectory.path
    #expect(path.hasSuffix("Library/Application Support/Shitsurae/backup"))
}

@Test func экспортВНедоступныйКаталогБросаетОшибкуВместоTrue() throws {
    let dir = try временнаяПапка()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: dir)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)

    let backup = DockBackup(directory: dir)
    #expect(throws: DockBackupError.self) {
        try backup.createIfNeeded()
    }
}

@Test func нулевойБайтовыйФайлНеСчитаетсяСуществующимБэкапом() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir)
    FileManager.default.createFile(atPath: backup.backupURL.path, contents: Data())

    #expect(backup.exists == false)
    #expect(try backup.createIfNeeded() == true)
    #expect(backup.exists == true)

    let data = try Data(contentsOf: backup.backupURL)
    #expect(!data.isEmpty)
}

/// Восстановление пишет в настоящий домен через `defaults import`, поэтому
/// тесты работают на выдуманном домене-однодневке и убирают его за собой.
private func временныйДомен() -> String {
    "io.github.lilmikazuki.shitsurae.tests.\(UUID().uuidString)"
}

private func удалитьДомен(_ domain: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["delete", domain]
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
}

private func записатьВДомен(_ domain: String, key: String, value: String) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["write", domain, key, value]
    try p.run()
    p.waitUntilExit()
}

private func прочитатьИзДомена(_ domain: String, key: String) -> String? {
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

@Test func восстановлениеБезБэкапаБросаетВнятнуюОшибку() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: временныйДомен())
    #expect(throws: DockBackupError.backupMissing) { try backup.restore() }
}

@Test func восстановлениеВозвращаетДоменКСостояниюБэкапа() throws {
    let domain = временныйДомен()
    defer { удалитьДомен(domain) }
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: domain)
    try записатьВДомен(domain, key: "marker", value: "original")
    #expect(try backup.createIfNeeded())

    try записатьВДомен(domain, key: "marker", value: "changed")
    #expect(прочитатьИзДомена(domain, key: "marker") == "changed")

    try backup.restore()
    #expect(прочитатьИзДомена(domain, key: "marker") == "original")
}

@Test func битыйФайлБэкапаНеСчитаетсяБэкапом() throws {
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: временныйДомен())
    try Data("не plist".utf8).write(to: backup.backupURL)

    #expect(backup.exists == false)
    #expect(throws: DockBackupError.backupMissing) { try backup.restore() }
}

/// Бэкап — единственная страховка, и терять её после первого же
/// использования нельзя: восстановиться можно сколько угодно раз.
@Test func восстановлениеНеУдаляетБэкап() throws {
    let domain = временныйДомен()
    defer { удалитьДомен(domain) }
    let dir = try временнаяПапка()
    defer { try? FileManager.default.removeItem(at: dir) }

    let backup = DockBackup(directory: dir, domain: domain)
    try записатьВДомен(domain, key: "marker", value: "original")
    try backup.createIfNeeded()
    try backup.restore()

    #expect(backup.exists)
}
