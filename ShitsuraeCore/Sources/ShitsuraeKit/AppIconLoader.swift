import AppKit
import Foundation

@MainActor
public final class AppIconLoader {
    private var cache: [String: NSImage] = [:]
    private var presence: [String: Bool] = [:]

    public init() {}

    public func isPresent(at path: String) -> Bool {
        if let known = presence[path] {
            return known
        }
        let exists = FileManager.default.fileExists(atPath: path)
        presence[path] = exists
        return exists
    }

    public func invalidate() {
        presence.removeAll()
        cache.removeAll()
    }

    public func icon(forAppAt path: String) -> NSImage? {
        guard isPresent(at: path) else { return nil }
        if let cached = cache[path] {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        cache[path] = icon
        return icon
    }
}
