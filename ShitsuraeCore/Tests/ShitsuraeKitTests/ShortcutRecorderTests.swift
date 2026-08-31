import AppKit
import Foundation
@testable import ShitsuraeKit
import Testing

private func key(
    _ characters: String,
    code: UInt16,
    flags: NSEvent.ModifierFlags = [],
    type: NSEvent.EventType = .keyDown
) -> NSEvent {
    NSEvent.keyEvent(
        with: type,
        location: .zero,
        modifierFlags: flags,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: code
    )!
}

private func release() -> NSEvent {
    NSEvent.keyEvent(
        with: .flagsChanged,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "",
        charactersIgnoringModifiers: "",
        isARepeat: false,
        keyCode: 55
    )!
}

@MainActor
private func recorderAndLayouts() -> (ShortcutRecorder, InMemoryHotkeys, [DockLayout]) {
    let hotkeys = InMemoryHotkeys()
    return (
        ShortcutRecorder(hotkeys: hotkeys),
        hotkeys,
        [testLayout("Work", order: 0), testLayout("Personal", order: 1)]
    )
}

@Test @MainActor func eventsAreIgnoredUntilRecordingStarts() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    #expect(recorder.handle(key("1", code: 18, flags: .command), among: layouts) == false)
}

@Test @MainActor func aShortcutIsHeldUntilTheKeysAreReleased() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    let id = layouts[0].id
    recorder.start(id)

    recorder.handle(key("1", code: 18, flags: [.command, .option]), among: layouts)
    #expect(recorder.hint == ShortcutCapture.releaseHint)
    #expect(recorder.label(for: id) != nil)
    #expect(recorder.recordingID == id, "still recording until the keys come up")

    recorder.handle(release(), among: layouts)
    #expect(recorder.recordingID == nil)
    #expect(recorder.label(for: id) != nil)
}

@Test @MainActor func escapeLeavesTheExistingShortcutAlone() {
    let (recorder, _, layouts) = recorderAndLayouts()
    let id = layouts[0].id

    recorder.start(id)
    recorder.handle(key("1", code: 18, flags: [.command, .option]), among: layouts)
    recorder.handle(release(), among: layouts)
    let assigned = recorder.label(for: id)
    #expect(assigned != nil)

    recorder.start(id)
    recorder.handle(key("2", code: 19, flags: .command), among: layouts)
    recorder.handle(key("\u{1B}", code: 53), among: layouts)

    #expect(recorder.recordingID == nil)
    #expect(recorder.label(for: id) == assigned, "cancelling must leave the old shortcut in place")
}

@Test @MainActor func aBareKeyIsRefusedWithAnExplanation() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    recorder.start(layouts[0].id)
    recorder.handle(key("k", code: 40), among: layouts)

    #expect(recorder.hint == ShortcutCapture.needsModifierHint)
    #expect(recorder.hintIsError)
    #expect(recorder.recordingID != nil, "a refusal keeps the recording open")
}

@Test @MainActor func restartingRecordingDropsTheHalfTypedShortcut() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    let first = layouts[0].id
    let second = layouts[1].id

    recorder.start(first)
    recorder.handle(key("3", code: 20, flags: .command), among: layouts)
    recorder.start(second)
    recorder.handle(release(), among: layouts)

    #expect(recorder.recordingID == second, "releasing with nothing typed keeps recording open")
    recorder.stop()
    #expect(
        recorder.label(for: second) == nil,
        "a keystroke meant for one layout must not land on another"
    )
    #expect(recorder.label(for: first) == nil)
}

@Test @MainActor func aTakenShortcutNamesItsOwnerAndChangesNothing() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    let first = layouts[0].id
    let second = layouts[1].id

    recorder.start(first)
    recorder.handle(key("4", code: 21, flags: [.command, .option]), among: layouts)
    recorder.handle(release(), among: layouts)

    recorder.start(second)
    recorder.handle(key("4", code: 21, flags: [.command, .option]), among: layouts)

    #expect(recorder.hint == ShortcutCapture.conflictHint("Work"))
    #expect(recorder.hintIsError)
    recorder.handle(release(), among: layouts)
    recorder.stop()
    #expect(recorder.label(for: second) == nil)
}

@Test @MainActor func recordingSilencesOurOwnGlobalHotkeys() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    #expect(hotkeys.enabled)

    recorder.start(layouts[0].id)
    #expect(hotkeys.enabled == false, "an armed hotkey would fire instead of reporting a conflict")

    recorder.stop()
    #expect(hotkeys.enabled)
}

@Test @MainActor func everyExitFromRecordingRearmsTheHotkeys() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    let id = layouts[0].id

    recorder.start(id)
    recorder.handle(key("\u{1B}", code: 53), among: layouts)
    #expect(hotkeys.enabled, "cancelling must not leave the user without shortcuts")

    recorder.start(id)
    recorder.handle(key("\u{8}", code: 51), among: layouts)
    #expect(hotkeys.enabled, "clearing must not leave the user without shortcuts")

    recorder.start(id)
    recorder.clear(for: id)
    #expect(hotkeys.enabled)
}

@Test @MainActor func losingFocusWhileRecordingRearmsTheHotkeys() {
    let (recorder, hotkeys, layouts) = recorderAndLayouts()
    recorder.start(layouts[0].id)
    #expect(hotkeys.enabled == false)

    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)

    #expect(recorder.recordingID == nil, "the key monitor is local; recording cannot outlive focus")
    #expect(hotkeys.enabled, "leaving the app must not cost the user every global shortcut")
}
