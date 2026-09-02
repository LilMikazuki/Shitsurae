import Foundation

public enum SidebarNote {
    public static func duplicates(_ files: [DuplicateLayoutFile]) -> String? {
        guard !files.isEmpty else { return nil }
        let layouts = Set(files.map(\.layoutName))
        if layouts.count == 1, let name = layouts.first {
            return files.count == 1
                ? "\"\(name)\" has an extra copy on disk. It isn't used."
                : "\"\(name)\" has \(files.count) extra copies on disk. They aren't used."
        }
        return "\(layouts.count) layouts have extra copies on disk. They aren't used."
    }

    public static func unreadable(_ files: [String]) -> String? {
        guard !files.isEmpty else { return nil }
        return files.count == 1
            ? "A file in your layouts folder can't be read and is skipped."
            : "\(files.count) files in your layouts folder can't be read and are skipped."
    }

    public static let revealTitle = "Show in Finder"
}
