import Foundation

public enum DockBackupError: Error, Equatable {
    case exportFailed(status: Int32)
    /// `defaults export` отчитался кодом 0, но по факту не создал пригодный бэкап.
    case exportProducedInvalidFile
}

extension DockBackupError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .exportFailed(status):
            "`defaults export` failed with exit status \(status)."
        case .exportProducedInvalidFile:
            "`defaults export` reported success but did not produce a valid backup file."
        }
    }
}

/// Полный экспорт домена `com.apple.dock` — страховка на случай,
/// если формат plist сменится или запись пойдёт не так.
/// Делается ровно один раз, перед самым первым применением пресета.
public struct DockBackup: Sendable {
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
        Self.isValidBackup(at: backupURL)
    }

    /// Возвращает `true`, если бэкап создан этим вызовом,
    /// и `false`, если он уже был — существующий не перезаписывается никогда.
    @discardableResult
    public func createIfNeeded() throws -> Bool {
        if exists {
            return false
        }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["export", CFPreferencesDockStore.domainName, backupURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DockBackupError.exportFailed(status: process.terminationStatus)
        }
        guard Self.isValidBackup(at: backupURL) else {
            throw DockBackupError.exportProducedInvalidFile
        }
        return true
    }

    /// `defaults export` возвращает код завершения 0 даже когда ничего не записал:
    /// каталог назначения недоступен на запись, путь назначения — сам каталог,
    /// или домен не существует (тогда пишется пустой plist). Поэтому валидность
    /// бэкапа проверяем по содержимому файла, а не по коду завершения процесса.
    private static func isValidBackup(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return false }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return false }
        guard let dict = plist as? [String: Any] else { return false }
        return !dict.isEmpty
    }
}
