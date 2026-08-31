import Foundation

public enum DockBackupError: Error, Equatable {
    case backupDirectoryUnavailable
    case exportCouldNotStart
    case exportFailed(status: Int32)
    case importCouldNotStart
    case exportProducedInvalidFile
    case backupMissing
    case importFailed(status: Int32)
    case importDidNotApply
}

extension DockBackupError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .backupDirectoryUnavailable:
            "The backup folder could not be created."
        case .exportCouldNotStart:
            "`defaults export` could not be started."
        case let .exportFailed(status):
            "`defaults export` failed with exit status \(status)."
        case .exportProducedInvalidFile:
            "`defaults export` reported success but did not produce a valid backup file."
        case .importCouldNotStart:
            "`defaults import` could not be started."
        case .backupMissing:
            "There is no usable backup to restore from."
        case let .importFailed(status):
            "`defaults import` failed with exit status \(status)."
        case .importDidNotApply:
            "`defaults import` reported success but the Dock domain did not change."
        }
    }
}

public struct DockBackup: Sendable {
    private let directory: URL
    private let domain: String

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
        let name = domain.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(name).original.plist")
    }

    public var exists: Bool {
        Self.isValidBackup(at: backupURL)
    }

    @discardableResult
    public func createIfNeeded() throws(DockBackupError) -> Bool {
        if exists {
            return false
        }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        } catch {
            throw DockBackupError.backupDirectoryUnavailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["export", domain, backupURL.path]
        do {
            try process.run()
        } catch {
            throw DockBackupError.exportCouldNotStart
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DockBackupError.exportFailed(status: process.terminationStatus)
        }
        guard Self.isValidBackup(at: backupURL) else {
            throw DockBackupError.exportProducedInvalidFile
        }
        return true
    }

    public func restore() throws(DockBackupError) {
        guard let expected = Self.contents(of: backupURL) else {
            throw DockBackupError.backupMissing
        }

        // `defaults import` merges: a setting the user turned on after the
        // backup was taken survives it. Clear those first, or the Dock keeps
        // them and the domain never matches what we promised to restore.
        let store = CFPreferencesDockStore(domain: domain)
        for key in DockKey.all where expected[key] == nil {
            store.setValue(nil, forKey: key)
        }
        store.synchronize()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["import", domain, backupURL.path]
        do {
            try process.run()
        } catch {
            throw DockBackupError.importCouldNotStart
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DockBackupError.importFailed(status: process.terminationStatus)
        }
        guard domainMatches(expected) else {
            throw DockBackupError.importDidNotApply
        }
    }

    private func domainMatches(_ expected: [String: Any]) -> Bool {
        let store = CFPreferencesDockStore(domain: domain)
        store.synchronize()
        for key in DockKey.all {
            let wanted = expected[key]
            let actual = store.value(forKey: key)
            if wanted == nil, actual == nil {
                continue
            }
            guard let wanted, let actual,
                  (actual as AnyObject).isEqual(wanted as AnyObject)
            else { return false }
        }
        return true
    }

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
