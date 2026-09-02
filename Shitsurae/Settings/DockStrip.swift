import AppKit
import ShitsuraeCore
import ShitsuraeKit
import SwiftUI
import UniformTypeIdentifiers

struct DockStrip: View {
    let model: AppModel
    let layout: DockLayout
    let icons: AppIconLoader

    private let tileSize: CGFloat = 64
    private let tileRadius: CGFloat = 16
    private let tileGap: CGFloat = 10
    private let stripRadius: CGFloat = 30

    @State private var draggingBundleId: String?
    @State private var dragShift: CGFloat = 0

    @State private var scrollOffset: CGFloat = 0
    @State private var scrollRoom: CGFloat = 0

    @State private var dropNote: String?

    var body: some View {
        VStack(spacing: 6) {
            strip
            ZStack {
                Text("⚠")
                    .font(.system(size: 13))
                    .hidden()

                if let shown {
                    HStack(spacing: 5) {
                        if shown.isWarning {
                            Text("⚠")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                        }
                        Text(shown.text)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(shown
                        .isWarning ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                }
            }
        }
        .onChange(of: layout.apps.map(\.bundleId)) { _, _ in
            dropNote = nil
            icons.invalidate()
        }
    }

    private var strip: some View {
        let drag = plannedDrag()
        let row = HStack(alignment: .bottom, spacing: tileGap) {
            ForEach(Array(layout.apps.enumerated()), id: \.element.bundleId) { index, app in
                tile(app, at: index, drag: drag)
            }
            addTile
        }
        .padding(EdgeInsets(top: 14, leading: 12, bottom: 11, trailing: 12))
        .animation(.snappy(duration: 0.18), value: layout.apps.map(\.bundleId))

        return ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) { row }
                .fixedSize(horizontal: false, vertical: true)
                .onScrollGeometryChange(for: ScrollProgress.self) { geometry in
                    ScrollProgress(
                        offset: geometry.contentOffset.x,
                        room: max(0, geometry.contentSize.width - geometry.containerSize.width)
                    )
                } action: { _, progress in
                    scrollOffset = progress.offset
                    scrollRoom = progress.room
                }
                .mask(edgeFade)
                .animation(.easeOut(duration: 0.15), value: atStart)
                .animation(.easeOut(duration: 0.15), value: atEnd)
        }
        .background(.quinary, in: .rect(cornerRadius: stripRadius))
        .overlay(
            RoundedRectangle(cornerRadius: stripRadius).strokeBorder(.separator, lineWidth: 0.5)
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            accept(providers)
        }
        .help("Drag tiles to reorder · drop an app to add · right-click for more")
    }

    private var atStart: Bool {
        scrollOffset <= 1
    }

    private var atEnd: Bool {
        scrollOffset >= scrollRoom - 1
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: atStart ? .black : .clear, location: 0),
                .init(color: .black, location: atStart ? 0 : 0.07),
                .init(color: .black, location: atEnd ? 1 : 0.93),
                .init(color: atEnd ? .black : .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func tile(_ app: DockApp, at index: Int, drag: TileDrag?) -> some View {
        let missing = !icons.isPresent(at: app.path)

        return Group {
            if let icon = icons.icon(forAppAt: app.path) {
                Image(nsImage: icon).resizable()
            } else {
                RoundedRectangle(cornerRadius: tileRadius)
                    .fill(.quaternary)
                    .overlay {
                        RoundedRectangle(cornerRadius: tileRadius)
                            .strokeBorder(
                                missing ? AnyShapeStyle(.orange) : AnyShapeStyle(.separator),
                                style: StrokeStyle(lineWidth: 0.5, dash: missing ? [3, 3] : [])
                            )
                    }
            }
        }
        .frame(width: tileSize, height: tileSize)
        .opacity(missing ? 0.45 : 1)
        .offset(x: shift(app, at: index, drag: drag))
        .animation(
            dragging(app) ? nil : .snappy(duration: 0.15),
            value: shift(app, at: index, drag: drag)
        )
        .scaleEffect(dragging(app) ? 1.08 : 1)
        .shadow(
            color: .black.opacity(dragging(app) ? 0.25 : 0),
            radius: dragging(app) ? 6 : 0,
            y: dragging(app) ? 3 : 0
        )
        .zIndex(dragging(app) ? 1 : 0)
        .pointerStyle(dragging(app) ? .grabActive : .grabIdle)
        // A hand-rolled gesture rather than `draggable`/`onDrag`: inside a
        // `ScrollView` the system drag never reaches the tile.
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if draggingBundleId == nil {
                        draggingBundleId = app.bundleId
                    }
                    guard dragging(app) else { return }
                    dragShift = value.translation.width
                }
                .onEnded { _ in
                    defer {
                        draggingBundleId = nil
                        dragShift = 0
                    }
                    guard dragging(app),
                          let drag = plannedDrag(),
                          let target = drag.target
                    else { return }
                    model.moveApp(in: layout.id, from: drag.from, to: target)
                }
        )
        .contextMenu {
            Button("Move Left") {
                model.moveApp(in: layout.id, from: index, to: index - 1)
            }
            .disabled(index == 0)

            Button("Move Right") {
                model.moveApp(in: layout.id, from: index, to: index + 1)
            }
            .disabled(index >= layout.apps.count - 1)

            Divider()

            Button("Remove from Layout", role: .destructive) {
                model.removeApp(in: layout.id, at: index)
            }
        }
        .help(app.label)
        .accessibilityLabel(
            missing ? "\(app.label), not found on disk, will be skipped" : app.label
        )
        .accessibilityAction(named: "Move Left") {
            model.moveApp(in: layout.id, from: index, to: index - 1)
        }
        .accessibilityAction(named: "Move Right") {
            model.moveApp(in: layout.id, from: index, to: index + 1)
        }
        .accessibilityAction(named: "Remove from Layout") {
            model.removeApp(in: layout.id, at: index)
        }
    }

    private var addTile: some View {
        Button(action: pickApplications) {
            RoundedRectangle(cornerRadius: tileRadius)
                .strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: tileSize, height: tileSize)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .help("Add an application to this layout")
        .accessibilityLabel("Add an application to this layout")
    }

    private func dragging(_ app: DockApp) -> Bool {
        draggingBundleId == app.bundleId
    }

    private func plannedDrag() -> TileDrag? {
        guard let id = draggingBundleId,
              let from = layout.apps.firstIndex(where: { $0.bundleId == id })
        else { return nil }

        return TileDrag(
            from: from,
            count: layout.apps.count,
            step: tileSize + tileGap,
            distance: dragShift
        )
    }

    private func shift(_ app: DockApp, at index: Int, drag: TileDrag?) -> CGFloat {
        if dragging(app) {
            return dragShift
        }
        return drag?.offset(forTileAt: index) ?? 0
    }

    private func accept(_ providers: [NSItemProvider]) -> Bool {
        let files = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !files.isEmpty else { return false }

        let collector = DropCollector(expected: files.count)
        for provider in files {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                let path = Self.url(from: item)?.standardizedFileURL.path
                guard let paths = collector.add(path) else { return }
                Task { @MainActor in
                    add(paths)
                }
            }
        }
        return true
    }

    private func add(_ paths: [String]) {
        let added = model.addApps(in: layout.id, atPaths: paths)
        guard added == 0 else {
            dropNote = nil
            return
        }
        dropNote = paths.count == 1
            ? "That file is not an application, or it is already here"
            : "None of those were applications you can add"
    }

    private nonisolated static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    private func pickApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        add(panel.urls.map(\.path))
    }

    private var note: LayoutNote? {
        LayoutNote.make(missing: layout.apps.filter { !icons.isPresent(at: $0.path) }.map(\.label))
    }

    private var shown: LayoutNote? {
        if let dropNote {
            return LayoutNote(text: dropNote, isWarning: true)
        }
        return note
    }
}

private struct ScrollProgress: Equatable {
    var offset: CGFloat
    var room: CGFloat
}

private final class DropCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let expected: Int
    private var paths: [String] = []
    private var seen = 0

    init(expected: Int) {
        self.expected = expected
    }

    func add(_ path: String?) -> [String]? {
        lock.lock()
        defer { lock.unlock() }
        if let path {
            paths.append(path)
        }
        seen += 1
        guard seen == expected else { return nil }
        return paths
    }
}
