import Foundation
@testable import ShitsuraeKit
import Testing

private func input(
    _ key: String,
    command: Bool = false,
    option: Bool = false,
    shift: Bool = false,
    control: Bool = false
) -> ShortcutInput {
    ShortcutInput(key: key, command: command, option: option, shift: shift, control: control)
}

@Test func aShortcutWithCommandIsAccepted() {
    #expect(ShortcutCapture.decide(input("1", command: true, option: true)) == .accept)
}

@Test func optionAloneIsEnough() {
    #expect(ShortcutCapture.decide(input("1", option: true)) == .accept)
}

@Test func escapeExitsRecording() {
    #expect(ShortcutCapture.decide(input("Escape")) == .cancel)
}

@Test func backspaceWithoutModifiersClearsTheShortcut() {
    #expect(ShortcutCapture.decide(input("Backspace")) == .clear)
}

@Test func backspaceWithAModifierIsAnOrdinaryShortcut() {
    #expect(ShortcutCapture.decide(input("Backspace", command: true)) == .accept)
}

@Test func pressingOnlyAModifierIsIgnored() {
    #expect(ShortcutCapture.decide(input("", command: true)) == .ignore)
}

@Test func shortcutIsRejectedWithoutCommandOrOption() {
    #expect(ShortcutCapture.decide(input("1")) == .needsModifier)
    #expect(ShortcutCapture.decide(input("1", shift: true)) == .needsModifier)
    #expect(ShortcutCapture.decide(input("1", control: true)) == .needsModifier)
    #expect(ShortcutCapture.decide(input("1", shift: true, control: true)) == .needsModifier)
}

@Test func theHintTextsMatchTheMockup() {
    #expect(ShortcutCapture.recordingHint == "Press a shortcut · ⌫ to clear · Esc to cancel")
    #expect(ShortcutCapture.needsModifierHint == "Add ⌘ or ⌥ to the shortcut.")
    #expect(ShortcutCapture.conflictHint("Work") == "Already used by \"Work\".")
    #expect(ShortcutCapture.releaseHint == "Release the keys to save")
    #expect(ShortcutCapture.singleKeyHint == "One key plus modifiers — keeping the last key")
}

@Test func timestampSaysNeverUsedWithoutALayout() {
    #expect(AppModel.lastUsedLabel(nil) == "Never used")
}

@Test func theTimestampStartsWithAPlainWord() {
    #expect(AppModel.lastUsedLabel(Date()).hasPrefix("Last used "))
}
