import Foundation
import Testing
@testable import ShitsuraeCore

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
