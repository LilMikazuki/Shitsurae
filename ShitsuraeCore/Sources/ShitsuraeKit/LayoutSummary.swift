import Foundation

public enum LayoutSummary {
    public static func appCount(_ layout: DockLayout) -> String {
        let count = layout.apps.count
        return "\(count) \(count == 1 ? "app" : "apps")"
    }
}
