import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class ShortcutRecorder {
    public private(set) var recordingID: UUID?
    public private(set) var hint: String?
    public private(set) var hintIsError = false

    private var pendingEvent: NSEvent?
    private var pendingLabel: String?
    private var revision = 0
    private var deactivation: (any NSObjectProtocol)?
    private let hotkeys: any Hotkeys
    private let log: any EventLog

    public init(hotkeys: any Hotkeys = HotkeyService(), log: any EventLog = SystemEventLog()) {
        self.hotkeys = hotkeys
        self.log = log
    }

    public func label(for id: UUID) -> String? {
        _ = revision
        guard recordingID == id else { return hotkeys.label(for: id) }
        return pendingLabel ?? "Recording…"
    }

    public func clear(for id: UUID) {
        hotkeys.clear(for: id)
        revision += 1
        if recordingID == id {
            stop()
        }
    }

    public func start(_ id: UUID) {
        pendingEvent = nil
        pendingLabel = nil
        hotkeys.setEnabled(false)
        // Recording unregisters the shortcuts, and the key monitor is local:
        // leaving the app would strand them until relaunch.
        deactivation = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        recordingID = id
        hint = ShortcutCapture.recordingHint
        hintIsError = false
    }

    public func stop() {
        if let deactivation {
            NotificationCenter.default.removeObserver(deactivation)
        }
        deactivation = nil
        hotkeys.setEnabled(true)
        recordingID = nil
        hint = nil
        hintIsError = false
        pendingEvent = nil
        pendingLabel = nil
    }

    public func register(_ ids: [UUID]) {
        hotkeys.register(ids)
    }

    public func onTrigger(_ handler: @escaping @MainActor (UUID) -> Void) {
        hotkeys.onTrigger(handler)
    }

    @discardableResult
    public func handle(_ event: NSEvent, among layouts: [DockLayout]) -> Bool {
        guard recordingID != nil else { return false }

        switch event.type {
        case .keyDown:
            return handleKeyDown(event, among: layouts)
        case .keyUp, .flagsChanged:
            commitIfReleased(event, among: layouts)
            return true
        default:
            return false
        }
    }

    private func handleKeyDown(_ event: NSEvent, among layouts: [DockLayout]) -> Bool {
        guard let id = recordingID else { return false }

        switch ShortcutCapture.decide(Self.input(from: event)) {
        case .ignore:
            return true

        case .cancel:
            stop()
            return true

        case .clear:
            hotkeys.clear(for: id)
            stop()
            return true

        case .needsModifier:
            reject(with: ShortcutCapture.needsModifierHint)
            return true

        case .accept:
            if let owner = hotkeys.owner(of: event, excluding: id, among: layouts.map(\.id)),
               let name = layouts.first(where: { $0.id == owner })?.name
            {
                reject(with: ShortcutCapture.conflictHint(name))
                return true
            }
            let replacesAnotherKey = pendingEvent.map { $0.keyCode != event.keyCode } ?? false

            pendingEvent = event
            pendingLabel = hotkeys.describe(event)
            hint = replacesAnotherKey ? ShortcutCapture.singleKeyHint : ShortcutCapture.releaseHint
            hintIsError = false
            return true
        }
    }

    private func reject(with message: String) {
        pendingEvent = nil
        pendingLabel = nil
        hint = message
        hintIsError = true
    }

    private func commitIfReleased(_ event: NSEvent, among _: [DockLayout]) {
        guard let id = recordingID, let pending = pendingEvent else { return }

        let held = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard held.isEmpty else { return }

        if !hotkeys.assign(pending, to: id) {
            log.record(.error, .hotkeys, "Storing the shortcut for layout \(id) failed")
        }
        revision += 1
        stop()
    }

    static func input(from event: NSEvent) -> ShortcutInput {
        let key: String = switch event.keyCode {
        case 53: "Escape"
        case 51: "Backspace"
        default: event.charactersIgnoringModifiers ?? ""
        }
        return ShortcutInput(
            key: key,
            command: event.modifierFlags.contains(.command),
            option: event.modifierFlags.contains(.option),
            shift: event.modifierFlags.contains(.shift),
            control: event.modifierFlags.contains(.control)
        )
    }
}
