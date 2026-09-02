import Foundation
import KeyboardShortcuts
@testable import ShitsuraeKit
import Testing

@MainActor
private final class RecordingBinding: ShortcutBinding {
    private(set) var bound: [String: Int] = [:]
    private(set) var unbound: [String: Int] = [:]
    private(set) var actions: [String: () -> Void] = [:]
    private(set) var enabled: [String: Bool] = [:]

    func bind(_ name: KeyboardShortcuts.Name, _ action: @escaping () -> Void) {
        bound[name.rawValue, default: 0] += 1
        actions[name.rawValue] = action
    }

    func unbind(_ name: KeyboardShortcuts.Name) {
        unbound[name.rawValue, default: 0] += 1
        bound[name.rawValue] = 0
        actions[name.rawValue] = nil
    }

    func setEnabled(_ enabled: Bool, for names: [KeyboardShortcuts.Name]) {
        for name in names {
            self.enabled[name.rawValue] = enabled
        }
    }
}

@Test @MainActor func registeringTwiceLeavesOneHandlerPerLayout() {
    let binding = RecordingBinding()
    let service = HotkeyService(binding: binding)
    let id = UUID()

    service.register([id])
    service.register([id])
    service.register([id])

    #expect(binding.bound["layout-\(id.uuidString)"] == 1, "one press must apply the layout once")
}

@Test @MainActor func aLayoutThatLeavesTheListIsUnbound() {
    let binding = RecordingBinding()
    let service = HotkeyService(binding: binding)
    let kept = UUID()
    let removed = UUID()

    service.register([kept, removed])
    service.register([kept])

    #expect(binding.bound["layout-\(kept.uuidString)"] == 1)
    #expect(binding.actions["layout-\(removed.uuidString)"] == nil)
}

@Test @MainActor func theTriggerReportsTheLayoutThatFired() {
    let binding = RecordingBinding()
    let service = HotkeyService(binding: binding)
    let id = UUID()
    var fired: [UUID] = []
    service.onTrigger { fired.append($0) }
    service.register([id])

    binding.actions["layout-\(id.uuidString)"]?()

    #expect(fired == [id])
}

@Test @MainActor func rebindingDuringRecordingKeepsTheHotkeysDisabled() {
    let binding = RecordingBinding()
    let service = HotkeyService(binding: binding)
    let id = UUID()
    service.register([id])

    service.setEnabled(false)
    #expect(binding.enabled["layout-\(id.uuidString)"] == false)

    service.register([id])

    #expect(
        binding.enabled["layout-\(id.uuidString)"] == false,
        "a reload mid-recording must not re-arm the shortcut being recorded over"
    )
}

@Test @MainActor func registeringAnUnchangedListTouchesNoBinding() {
    let binding = RecordingBinding()
    let service = HotkeyService(binding: binding)
    let a = UUID()
    let b = UUID()

    service.register([a, b])
    service.register([a, b])
    service.register([a, b])

    #expect(binding.bound["layout-\(a.uuidString)"] == 1)
    #expect(binding.bound["layout-\(b.uuidString)"] == 1)
    #expect(binding.unbound.isEmpty)
}

@Test @MainActor func aLayoutJoiningTheListWhileRecordingStaysDisabled() {
    let binding = RecordingBinding()
    let service = HotkeyService(binding: binding)
    let a = UUID()
    let b = UUID()

    service.register([a])
    service.setEnabled(false)
    service.register([a, b])

    #expect(binding.enabled["layout-\(b.uuidString)"] == false)
    #expect(binding.unbound["layout-\(a.uuidString)"] == nil)
}
