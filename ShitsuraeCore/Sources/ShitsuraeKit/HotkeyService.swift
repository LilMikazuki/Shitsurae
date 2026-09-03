import AppKit
import Foundation
import KeyboardShortcuts

@MainActor
protocol ShortcutBinding {
    func bind(_ name: KeyboardShortcuts.Name, _ action: @escaping () -> Void)
    func unbind(_ name: KeyboardShortcuts.Name)
    func setEnabled(_ enabled: Bool, for names: [KeyboardShortcuts.Name])
}

@MainActor
struct LiveShortcutBinding: ShortcutBinding {
    func bind(_ name: KeyboardShortcuts.Name, _ action: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: name, action: action)
    }

    func unbind(_ name: KeyboardShortcuts.Name) {
        KeyboardShortcuts.removeHandler(for: name)
    }

    func setEnabled(_ enabled: Bool, for names: [KeyboardShortcuts.Name]) {
        if enabled {
            KeyboardShortcuts.enable(names)
        } else {
            KeyboardShortcuts.disable(names)
        }
    }
}

@MainActor
public protocol Hotkeys {
    func label(for id: UUID) -> String?
    func describe(_ event: NSEvent) -> String?
    func owner(of event: NSEvent, excluding id: UUID, among ids: [UUID]) -> UUID?
    @discardableResult func assign(_ event: NSEvent, to id: UUID) -> Bool
    func clear(for id: UUID)
    func setEnabled(_ enabled: Bool)
    func onTrigger(_ handler: @escaping @MainActor (UUID) -> Void)
    func register(_ ids: [UUID])
}

@MainActor
public final class HotkeyService: Hotkeys {
    private var handler: ((UUID) -> Void)?
    private var registered: Set<UUID> = []
    private var armed = true
    private let binding: any ShortcutBinding
    private let log: any EventLog

    public init(log: any EventLog = SystemEventLog()) {
        binding = LiveShortcutBinding()
        self.log = log
    }

    init(binding: any ShortcutBinding, log: any EventLog = SystemEventLog()) {
        self.binding = binding
        self.log = log
    }

    private func name(for id: UUID) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name("layout-\(id.uuidString)")
    }

    public func label(for id: UUID) -> String? {
        KeyboardShortcuts.getShortcut(for: name(for: id))?.description
    }

    public func describe(_ event: NSEvent) -> String? {
        KeyboardShortcuts.Shortcut(event: event)?.description
    }

    public func owner(of event: NSEvent, excluding id: UUID, among ids: [UUID]) -> UUID? {
        guard let candidate = KeyboardShortcuts.Shortcut(event: event) else { return nil }
        return ids.first { other in
            other != id && KeyboardShortcuts.getShortcut(for: name(for: other)) == candidate
        }
    }

    @discardableResult
    public func assign(_ event: NSEvent, to id: UUID) -> Bool {
        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else { return false }
        KeyboardShortcuts.setShortcut(shortcut, for: name(for: id))
        return true
    }

    public func setEnabled(_ enabled: Bool) {
        armed = enabled
        binding.setEnabled(enabled, for: registered.map(name(for:)))
    }

    public func clear(for id: UUID) {
        KeyboardShortcuts.reset(name(for: id))
    }

    public func onTrigger(_ handler: @escaping @MainActor (UUID) -> Void) {
        self.handler = handler
    }

    public func register(_ ids: [UUID]) {
        let wanted = Set(ids)
        for id in registered.subtracting(wanted) {
            binding.unbind(name(for: id))
        }
        for id in wanted.subtracting(registered) {
            // `onKeyUp` appends, so binding an id that is already bound makes one
            // press apply its layout twice.
            binding.bind(name(for: id)) { [weak self] in
                self?.log.record(.notice, .hotkeys, "Shortcut fired for layout \(id)")
                self?.handler?(id)
            }
            if !armed {
                // Binding registers the shortcut with the system, which would
                // re-arm it under an open recording.
                binding.setEnabled(false, for: [name(for: id)])
            }
        }
        registered = wanted
        log.record(.debug, .hotkeys, "Registered \(wanted.count) shortcuts")
    }
}
