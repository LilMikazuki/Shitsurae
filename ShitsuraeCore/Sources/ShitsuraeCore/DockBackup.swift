import Foundation

public enum DockBackupError: Error, Equatable {
    case exportFailed(status: Int32)
    /// `defaults export` отчитался кодом 0, но по факту не создал пригодный бэкап.
    case exportProducedInvalidFile
    /// Восстанавливать нечего: пригодного бэкапа не существует.
    case backupMissing
    case importFailed(status: Int32)
    /// `defaults import` отчитался кодом 0, но домен не стал бэкапом.
    case importDidNotApply
}

extension DockBackupError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .exportFailed(status):
            "`defaults export` failed with exit status \(status)."
        case .exportProducedInvalidFile:
            "`defaults export` reported success but did not produce a valid backup file."
        case .backupMissing:
            "There is no backup to restore from."
        case let .importFailed(status):
            "`defaults import` failed with exit status \(status)."
        case .importDidNotApply:
            "`defaults import` reported success but the Dock domain did not change."
        }
    }
}

/// Полный экспорт домена `com.apple.dock` — страховка на случай,
/// если формат plist сменится или запись пойдёт не так.
/// Делается ровно один раз, перед самым первым применением пресета.
public struct DockBackup: Sendable {
    private let directory: URL
    private let domain: String

    /// Домен вынесен в параметр только ради тестов: восстановление пишет
    /// в настоящие настройки, и гонять это на `com.apple.dock` нельзя.
    public init(directory: URL, domain: String = DockKey.domain) {
        self.directory = directory
        self.domain = domain
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
        process.arguments = ["export", domain, backupURL.path]
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

    /// Возвращает домен к состоянию бэкапа. Сам бэкап остаётся на месте:
    /// восстановиться можно сколько угодно раз, и терять единственную
    /// страховку после первого же использования нельзя.
    ///
    /// Перезапуск Dock сюда не входит — это дело вызывающего.
    ///
    /// Код возврата `defaults import` доверия не заслуживает ровно так же,
    /// как код возврата `defaults export`: тот отдаёт 0 и когда каталог
    /// назначения только для чтения, и когда домена не существует. Проверено
    /// на живой macOS 26.5.2 — именно поэтому `createIfNeeded()` рядом судит
    /// об успехе по содержимому файла. Восстановление — последняя линия
    /// обороны пользователя, и «молча не сработало» здесь недопустимо,
    /// поэтому после импорта домен перечитывается и сверяется с бэкапом.
    public func restore() throws {
        guard let expected = Self.contents(of: backupURL) else {
            throw DockBackupError.backupMissing
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["import", domain, backupURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DockBackupError.importFailed(status: process.terminationStatus)
        }
        guard domainMatches(expected) else {
            throw DockBackupError.importDidNotApply
        }
    }

    /// Сверяем подмножеством, а не полным равенством: демон настроек вправе
    /// дописать в домен свои ключи сразу после импорта, и требовать
    /// побайтового совпадения значило бы ловить ложные отказы.
    private func domainMatches(_ expected: [String: Any]) -> Bool {
        let store = CFPreferencesDockStore(domain: domain)
        for (key, value) in expected {
            guard let actual = store.value(forKey: key) else { return false }
            guard (actual as AnyObject).isEqual(value as AnyObject) else { return false }
        }
        return true
    }

    /// `defaults export` возвращает код завершения 0 даже когда ничего не записал:
    /// каталог назначения недоступен на запись, путь назначения — сам каталог,
    /// или домен не существует (тогда пишется пустой plist). Поэтому валидность
    /// бэкапа проверяем по содержимому файла, а не по коду завершения процесса.
    private static func isValidBackup(at url: URL) -> Bool {
        contents(of: url) != nil
    }

    private static func contents(of url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any], !dict.isEmpty
        else { return nil }
        return dict
    }
}
