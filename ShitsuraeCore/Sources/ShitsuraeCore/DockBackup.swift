import Foundation

public enum DockBackupError: Error, Equatable {
    case exportFailed(status: Int32)
}

/// Полный экспорт домена `com.apple.dock` — страховка на случай,
/// если формат plist сменится или запись пойдёт не так.
/// Делается ровно один раз, перед самым первым применением пресета.
public struct DockBackup {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Shitsurae/backup")
    }

    public var backupURL: URL {
        directory.appendingPathComponent("com.apple.dock.original.plist")
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: backupURL.path)
    }

    /// Возвращает `true`, если бэкап создан этим вызовом,
    /// и `false`, если он уже был — существующий не перезаписывается никогда.
    @discardableResult
    public func createIfNeeded() throws -> Bool {
        if exists { return false }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["export", CFPreferencesDockStore.domainName, backupURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DockBackupError.exportFailed(status: process.terminationStatus)
        }
        return true
    }
}
