import AppKit
import Foundation
import Observation
import ShitsuraeCore

/// Exactly one reason — `writtenButNotApplied` — means the Dock has already
/// changed. Merging it with the others would make the messages lie.
public enum ShitsuraeFailure: Equatable, Sendable {
    case unreadableLayout
    case unsupportedSetting(key: String, value: String)
    case unsupportedTile(String)
    case writeFailed
    case writtenButNotApplied

    public init(from error: Error) {
        switch error {
        case let error as DockReadError:
            switch error {
            case let .unsupportedTileType(_, tileType):
                self = .unsupportedTile(tileType)
            case let .unsupportedValue(key, value):
                self = .unsupportedSetting(key: key, value: value)
            case .wrongType, .malformedTile:
                self = .unreadableLayout
            }
        case is DockWriteError:
            self = .writeFailed
        case is DockRestartError:
            self = .writtenButNotApplied
        default:
            self = .unreadableLayout
        }
    }
}

public enum ShitsuraeAlertKind: Equatable, Sendable {
    case saveFailed
    case delete(id: UUID, name: String)
    case failure(ShitsuraeFailure)
}

@MainActor
@Observable
public final class AppModel {
    public private(set) var layouts: [DockLayout] = []
    private var selectedLayoutIDMirror: UUID?

    public var selectedLayoutID: UUID? {
        get { selectedLayoutIDMirror }
        set {
            selectedLayoutIDMirror = newValue
            if let recording = shortcuts.recordingID, recording != newValue {
                shortcuts.stop()
            }
        }
    }

    public var alert: ShitsuraeAlertKind?

    private let quitter: any AppQuitting
    private let store: LayoutStore
    private let switcher: SwitchService
    public let shortcuts: ShortcutRecorder

    public init(
        store: LayoutStore,
        switcher: SwitchService,
        shortcuts: ShortcutRecorder = ShortcutRecorder(),
        quitter: any AppQuitting = WorkspaceAppQuitter()
    ) {
        self.store = store
        self.switcher = switcher
        self.shortcuts = shortcuts
        self.quitter = quitter
        activeLayoutID = switcher.lastAppliedLayoutID
    }

    /// Mirrors rather than service lookups: the services keep this state in
    /// `UserDefaults` and on disk, where observation cannot see it.
    public private(set) var activeLayoutID: UUID?

    public private(set) var unreadableFiles: [String] = []

    public private(set) var storeUnavailable = false

    /// The Dock has one arrangement, so it gets one writer. Two applies in
    /// flight would interleave preference writes and leave the active mark
    /// describing whichever finished last.
    public private(set) var isChangingDock = false

    private func syncServices() {
        activeLayoutID = switcher.lastAppliedLayoutID
    }

    public var selectedLayout: DockLayout? {
        layouts.first { $0.id == selectedLayoutID }
    }

    public func reload() {
        if let loaded = try? store.load() {
            layouts = loaded.layouts
            unreadableFiles = loaded.unreadable
            storeUnavailable = false
        } else {
            storeUnavailable = true
        }
        if selectedLayout == nil {
            selectedLayoutID = layouts.first?.id
        }
        shortcuts.register(layouts.map(\.id))
        syncServices()
    }

    public func apply(id: UUID) async {
        guard !isChangingDock else { return }
        guard let snapshot = layouts.first(where: { $0.id == id }) else { return }
        isChangingDock = true
        defer { isChangingDock = false }
        let switcher = switcher
        // The skip is allowed only for the already-active layout: the active mark is set only
        // after a successful apply including the restart, so after a refused restart there is no
        // mark and the retry takes the normal writing path.
        let reapplying = id == activeLayoutID
        do {
            try await offMainThread {
                if reapplying {
                    try switcher.applyIfNeeded(snapshot)
                } else {
                    try switcher.apply(snapshot)
                }
            }
            if snapshot.quitsOtherApps {
                quitOthers(for: snapshot)
            }
            selectedLayoutID = id
            guard var fresh = layouts.first(where: { $0.id == id }) else {
                switcher.lastAppliedLayoutID = nil
                reload()
                return
            }
            guard fresh.dockState == snapshot.dockState else {
                switcher.lastAppliedLayoutID = nil
                reload()
                return
            }
            fresh.lastUsedAt = Date()
            try? store.save(fresh)
            reload()
        } catch {
            alert = .failure(ShitsuraeFailure(from: error))
            syncServices()
        }
    }

    private func quitOthers(for layout: DockLayout) {
        // A layout whose applications are all gone writes an empty Dock, and
        // "everything outside an empty layout" is every app the user has open.
        guard !layout.dockState(skippingMissing: .default).apps.isEmpty else { return }
        let kept = Set(layout.apps.map(\.bundleId))
        quitter.quit(bundleIds: quitter.runningBundleIds().subtracting(kept))
    }

    public func saveCurrentDock(named name: String) throws {
        let state: DockState
        do {
            state = try switcher.readCurrentState()
        } catch {
            alert = .failure(ShitsuraeFailure(from: error))
            throw error
        }

        let layout = DockLayout(
            order: (layouts.map(\.order).max() ?? -1) + 1,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            state: state
        ).withUniqueApps()
        do {
            try store.save(layout)
        } catch {
            alert = .saveFailed
            throw error
        }
        reload()
        selectedLayoutID = layout.id
    }

    public func seedInitialLayoutIfNeeded() {
        guard layouts.isEmpty, unreadableFiles.isEmpty, !storeUnavailable else { return }
        guard let state = try? switcher.readCurrentState() else { return }

        let layout = DockLayout(order: 0, name: "Dock 1", state: state).withUniqueApps()
        do {
            try store.save(layout)
        } catch {
            return
        }

        switcher.lastAppliedLayoutID = layout.id
        reload()
        selectedLayoutID = layout.id
    }

    public func deleteSelected() {
        guard let id = selectedLayoutID else { return }
        delete(id: id)
    }

    public func delete(id: UUID) {
        do {
            try store.delete(id: id)
        } catch {
            return
        }
        shortcuts.clear(for: id)
        if activeLayoutID == id {
            switcher.lastAppliedLayoutID = nil
        }
        selectedLayoutID = nil
        reload()
    }

    @discardableResult
    public func rename(id: UUID, to name: String) -> Bool {
        guard var layout = layouts.first(where: { $0.id == id }) else { return false }

        let others = layouts.filter { $0.id != id }.map(\.name)
        guard LayoutNameValidator.problem(for: name, existing: others) == nil else {
            return false
        }

        layout.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.save(layout)
        } catch {
            alert = .saveFailed
            return false
        }
        reload()
        return true
    }

    public func setQuitsOtherApps(id: UUID, _ on: Bool) {
        guard var layout = layouts.first(where: { $0.id == id }),
              layout.quitsOtherApps != on
        else { return }

        layout.quitsOtherApps = on
        do {
            try store.save(layout)
        } catch {
            alert = .saveFailed
            return
        }
        reload()
    }

    public func moveApp(in id: UUID, from: Int, to: Int) {
        guard from != to else { return }
        moveApps(in: id, fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    public func moveApps(in id: UUID, fromOffsets source: IndexSet, toOffset destination: Int) {
        mutate(id) { Self.move(&$0.apps, fromOffsets: source, toOffset: destination) }
    }

    /// Not SwiftUI's `move(fromOffsets:toOffset:)`: that lives in a SwiftUI
    /// extension, and the model does not import the UI. Same semantics.
    static func move(
        _ apps: inout [DockApp],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) {
        let moved = source.sorted().compactMap { apps.indices.contains($0) ? apps[$0] : nil }
        guard !moved.isEmpty else { return }

        for index in source.sorted(by: >) where apps.indices.contains(index) {
            apps.remove(at: index)
        }
        let shift = source.filter { $0 < destination }.count
        let target = min(max(destination - shift, 0), apps.count)
        apps.insert(contentsOf: moved, at: target)
    }

    public func removeApp(in id: UUID, at index: Int) {
        mutate(id) { layout in
            guard layout.apps.indices.contains(index) else { return }
            layout.apps.remove(at: index)
        }
    }

    @discardableResult
    public func addApp(in id: UUID, atPath path: String, insertingAt index: Int? = nil) -> Bool {
        addApps(in: id, atPaths: [path], insertingAt: index) == 1
    }

    @discardableResult
    public func addApps(
        in id: UUID,
        atPaths paths: [String],
        insertingAt index: Int? = nil
    ) -> Int {
        let apps = paths.compactMap(Self.dockApp(atPath:))
        guard !apps.isEmpty else { return 0 }

        var added = 0
        mutate(id) { layout in
            var at = min(index ?? layout.apps.count, layout.apps.count)
            for app in apps where !layout.apps.contains(where: { $0.bundleId == app.bundleId }) {
                layout.apps.insert(app, at: at)
                at += 1
                added += 1
            }
        }
        return added
    }

    static func dockApp(atPath path: String) -> DockApp? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.pathExtension == "app",
              let bundleId = Bundle(url: url)?.bundleIdentifier
        else { return nil }

        let shown = FileManager.default.displayName(atPath: url.path)
        let label = shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown

        return DockApp(path: url.path, bundleId: bundleId, label: label)
    }

    private func mutate(_ id: UUID, _ change: (inout DockLayout) -> Void) {
        guard var layout = layouts.first(where: { $0.id == id }) else { return }
        let before = layout
        change(&layout)
        guard layout != before else { return }
        do {
            try store.save(layout)
        } catch {
            alert = .saveFailed
            return
        }
        if id == switcher.lastAppliedLayoutID {
            switcher.lastAppliedLayoutID = nil
        }
        reload()
    }

    private nonisolated static let lastUsedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    public nonisolated static func lastUsedLabel(_ date: Date?) -> String {
        guard let date else { return "Never used" }
        return "Last used \(lastUsedFormatter.string(from: date))"
    }

    public func askDelete() {
        guard let layout = selectedLayout else { return }
        alert = .delete(id: layout.id, name: layout.name)
    }

    public func dismissAlert() {
        alert = nil
    }

    public func confirmAlert() async {
        switch alert {
        case let .delete(id, _):
            alert = nil
            delete(id: id)
        case .failure, .saveFailed, nil:
            alert = nil
        }
    }
}

/// `defaults` runs as a subprocess and the Dock restart waits on it, so this
/// work blocks its thread outright. The cooperative pool has one thread per
/// core and must not be one of them.
private func offMainThread<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws
    -> T
{
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(with: Result { try work() })
        }
    }
}
