import Foundation

public struct LayoutNote: Equatable, Sendable {
    public var text: String
    public var isWarning: Bool

    public init(text: String, isWarning: Bool) {
        self.text = text
        self.isWarning = isWarning
    }

    public static func make(missing: [String]) -> LayoutNote? {
        guard !missing.isEmpty else { return nil }
        return LayoutNote(
            text: "\(missing.joined(separator: ", ")) not found on disk — will be skipped",
            isWarning: true
        )
    }
}
