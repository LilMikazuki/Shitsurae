import Foundation

public enum DockStateFormatter {
    public static func plainText(_ state: DockState) -> String {
        var lines: [String] = []
        lines.append("Apps (\(state.apps.count)):")
        for app in state.apps {
            lines.append("  \(app.label)  [\(app.bundleId)]")
            lines.append("      \(app.path)")
        }
        lines.append("")
        lines.append("Settings:")
        lines.append("  tilesize: \(describe(state.settings.tilesize))")
        lines.append("  largesize: \(describe(state.settings.largesize))")
        lines.append("  magnification: \(describe(state.settings.magnification))")
        lines.append("  autohide: \(describe(state.settings.autohide))")
        lines.append("  orientation: \(describe(state.settings.orientation?.rawValue))")
        lines.append("  show-recents: \(describe(state.settings.showRecents))")
        return lines.joined(separator: "\n")
    }

    private static func describe(_ value: (some Any)?) -> String {
        value.map { "\($0)" } ?? "(default)"
    }
}
