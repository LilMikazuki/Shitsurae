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
