import Foundation

public struct LoadedLayouts: Equatable, Sendable {
    public var layouts: [DockLayout]
    public var unreadable: [String]

    public init(layouts: [DockLayout], unreadable: [String] = []) {
        self.layouts = layouts
        self.unreadable = unreadable
    }
}

public struct LayoutStore: Sendable {
    private let directory: URL

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

        var layouts: [DockLayout] = []
        var unreadable: [String] = []
        let decoder = JSONDecoder()
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let layout = try? decoder.decode(DockLayout.self, from: data)
            else {
                unreadable.append(file.lastPathComponent)
                continue
            }
            layouts.append(layout.withUniqueApps())
        }
        return LoadedLayouts(
            layouts: layouts.sorted { $0.order < $1.order },
            unreadable: unreadable.sorted()
        )
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
        do {
            try FileManager.default.removeItem(at: url(for: id))
        } catch CocoaError.fileNoSuchFile {}
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
