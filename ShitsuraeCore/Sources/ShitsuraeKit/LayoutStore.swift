import Foundation

public struct DuplicateLayoutFile: Equatable, Sendable {
    public var name: String
    public var layoutName: String

    public init(name: String, layoutName: String) {
        self.name = name
        self.layoutName = layoutName
    }
}

public struct LoadedLayouts: Equatable, Sendable {
    public var layouts: [DockLayout]
    public var unreadable: [String]
    public var duplicates: [DuplicateLayoutFile]

    public init(
        layouts: [DockLayout],
        unreadable: [String] = [],
        duplicates: [DuplicateLayoutFile] = []
    ) {
        self.layouts = layouts
        self.unreadable = unreadable
        self.duplicates = duplicates
    }
}

public struct LayoutStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        directory(under: supportDirectory)
    }

    static func directory(under support: URL) -> URL {
        let current = support.appendingPathComponent("layouts")
        let legacy = support.appendingPathComponent("presets")
        let manager = FileManager.default
        if !manager.fileExists(atPath: current.path), manager.fileExists(atPath: legacy.path) {
            return legacy
        }
        return current
    }

    private static var supportDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Shitsurae")
    }

    public static func migrateLegacyDirectory() {
        migrate(
            from: supportDirectory.appendingPathComponent("presets"),
            to: supportDirectory.appendingPathComponent("layouts")
        )
    }

    @discardableResult
    static func migrate(from legacy: URL, to current: URL) -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: legacy.path),
              !manager.fileExists(atPath: current.path)
        else { return false }
        return (try? manager.moveItem(at: legacy, to: current)) != nil
    }

    public func load() throws -> LoadedLayouts {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            )
        } catch CocoaError.fileReadNoSuchFile {
            return LoadedLayouts(layouts: [])
        }

        let decoder = JSONDecoder()
        var unreadable: [String] = []
        var decoded: [(name: String, layout: DockLayout)] = []
        for file in files
            .filter({ $0.pathExtension == "json" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        {
            guard let data = try? Data(contentsOf: file),
                  let layout = try? decoder.decode(DockLayout.self, from: data)
            else {
                unreadable.append(file.lastPathComponent)
                continue
            }
            decoded.append((file.lastPathComponent, layout))
        }

        var idAt: [String: UUID] = [:]
        for entry in decoded {
            idAt[entry.name] = entry.layout.id
        }

        var winners: [DockLayout] = []
        var shownName: [UUID: String] = [:]
        var losers: [(name: String, id: UUID)] = []
        for entry in decoded {
            let address = "\(entry.layout.id.uuidString).json"
            if shownName[entry.layout.id] != nil {
                losers.append((entry.name, entry.layout.id))
            } else if entry.name == address || idAt[address] != entry.layout.id {
                shownName[entry.layout.id] = entry.layout.name
                winners.append(entry.layout.withUniqueApps())
            } else {
                losers.append((entry.name, entry.layout.id))
            }
        }

        let duplicates = losers
            .map { DuplicateLayoutFile(name: $0.name, layoutName: shownName[$0.id] ?? "") }
            .sorted { $0.name < $1.name }

        return LoadedLayouts(
            layouts: winners.sorted { $0.order < $1.order },
            unreadable: unreadable.sorted(),
            duplicates: duplicates
        )
    }

    public func adoptStrayFiles() {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }

        var names = Set(files.map(\.lastPathComponent))
        let decoder = JSONDecoder()
        for file in files
            .filter({ $0.pathExtension == "json" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        {
            guard let data = try? Data(contentsOf: file),
                  let layout = try? decoder.decode(DockLayout.self, from: data)
            else { continue }

            let address = "\(layout.id.uuidString).json"
            guard file.lastPathComponent != address, !names.contains(address) else { continue }
            if (try? manager.moveItem(at: file, to: directory.appendingPathComponent(address)))
                != nil
            {
                names.insert(address)
            }
        }
    }

    public func save(_ layout: DockLayout) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(layout).write(to: url(for: layout.id), options: .atomic)
    }

    public func saveAll(_ layouts: [DockLayout]) throws {
        for layout in layouts {
            try save(layout)
        }
    }

    public func delete(id: UUID) throws {
        let manager = FileManager.default
        let address = url(for: id)
        if let files = try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) {
            let decoder = JSONDecoder()
            for file in files where file.pathExtension == "json"
                && file.lastPathComponent != address.lastPathComponent
            {
                guard let data = try? Data(contentsOf: file),
                      let layout = try? decoder.decode(DockLayout.self, from: data),
                      layout.id == id
                else { continue }
                try manager.removeItem(at: file)
            }
        }

        do {
            try manager.removeItem(at: address)
        } catch CocoaError.fileNoSuchFile {}
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
