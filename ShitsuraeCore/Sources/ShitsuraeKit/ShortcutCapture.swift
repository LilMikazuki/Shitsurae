import Foundation

public struct ShortcutInput: Equatable, Sendable {
    public var key: String
    public var command: Bool
    public var option: Bool
    public var shift: Bool
    public var control: Bool

    public init(
        key: String,
        command: Bool = false,
        option: Bool = false,
        shift: Bool = false,
        control: Bool = false
    ) {
        self.key = key
        self.command = command
        self.option = option
        self.shift = shift
        self.control = control
    }
}

public enum ShortcutDecision: Equatable, Sendable {
    case accept
    case clear
    case cancel
    case ignore
    case needsModifier
}

public enum ShortcutCapture {
    public static func decide(_ input: ShortcutInput) -> ShortcutDecision {
        guard !input.key.isEmpty else { return .ignore }
        if input.key == "Escape" {
            return .cancel
        }

        let bare = !input.command && !input.option && !input.shift && !input.control
        if input.key == "Backspace", bare {
            return .clear
        }

        guard input.command || input.option else { return .needsModifier }
        return .accept
    }

    public static let recordingHint = "Press a shortcut · ⌫ to clear · Esc to cancel"
    public static let needsModifierHint = "Add ⌘ or ⌥ to the shortcut."
    public static let releaseHint = "Release the keys to save"
    public static let singleKeyHint = "One key plus modifiers — keeping the last key"

    public static func conflictHint(_ layoutName: String) -> String {
        "Already used by \"\(layoutName)\"."
    }
}
