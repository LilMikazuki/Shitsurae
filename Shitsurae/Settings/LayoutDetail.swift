import ShitsuraeKit
import SwiftUI

struct LayoutDetail: View {
    @Bindable var model: AppModel
    let layout: DockLayout
    let icons: AppIconLoader

    @State private var monitor: Any?

    private var isApplied: Bool {
        layout.id == model.activeLayoutID
    }

    private var hotkeySubtitleStyle: AnyShapeStyle {
        isRecording && model.shortcuts.hintIsError
            ? AnyShapeStyle(.red)
            : AnyShapeStyle(.secondary)
    }

    private var hotkeySubtitle: String {
        guard isRecording else { return "Applies this layout from anywhere" }
        return model.shortcuts.hint ?? ShortcutCapture.recordingHint
    }

    private var isRecording: Bool {
        model.shortcuts.recordingID == layout.id
    }

    private var hotkeyTitle: String {
        guard isRecording else { return "Hotkey" }
        return model.shortcuts.hint ?? ShortcutCapture.recordingHint
    }

    var body: some View {
        VStack(spacing: 0) {
            strip
            Divider()
            form
        }
        .onChange(of: isRecording) { _, recording in
            recording ? startMonitor() : stopMonitor()
        }
        .onChange(of: layout.id) { _, _ in
            stopMonitor()
        }
        .onDisappear {
            stopMonitor()
            model.shortcuts.stop()
        }
    }

    private var strip: some View {
        DockStrip(model: model, layout: layout, icons: icons)
            .padding(EdgeInsets(top: 60, leading: 20, bottom: 18, trailing: 20))
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent("Apply to Dock") { applyButton }
                LabeledContent("Last used", value: AppModel.lastUsedLabel(layout.lastUsedAt))
                LabeledContent("Apps in layout", value: LayoutSummary.appCount(layout))
            }

            Section {
                LabeledContent {
                    hotkeyPill
                } label: {
                    Text("Hotkey")
                    Text(hotkeySubtitle)
                        .foregroundStyle(hotkeySubtitleStyle)
                }

                LabeledContent {
                    Toggle("Auto-Quit Apps", isOn: $model.quitsOtherApps)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                } label: {
                    Text("Auto-Quit Apps")
                    Text("Quits apps outside the layout you apply, for every layout")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var applyButton: some View {
        // Both states stay buttons of the same control size: swapping the applied state for a plain
        // label changed the row's height and made the whole form jump when a layout was applied.
        if isApplied {
            Button {} label: {
                Label("Applied", systemImage: "checkmark")
            }
            .buttonStyle(.bordered)
            .disabled(true)
            .help("This layout is already in your Dock")
        } else {
            Button("Apply") {
                Task {
                    await model.apply(id: layout.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isChangingDock)
            .help("Apply this layout to your Dock")
        }
    }

    private var hotkeyPill: some View {
        Button {
            model.selectedLayoutID = layout.id
            model.shortcuts.start(layout.id)
        } label: {
            Text(model.shortcuts.label(for: layout.id) ?? "Record")
                .font(.body.monospaced())
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? Color.accentColor : nil)
        .pointerStyle(.link)
        .contextMenu {
            Button("Clear Shortcut", role: .destructive) {
                model.shortcuts.clear(for: layout.id)
            }
            .disabled(model.shortcuts.label(for: layout.id) == nil)
        }
        .help(
            model.shortcuts.label(for: layout.id) == nil
                ? "Set a global shortcut for this layout"
                : "Click to change · right-click to clear"
        )
    }

    private func startMonitor() {
        stopMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
            event in
            model.shortcuts.handle(event, among: model.layouts) ? nil : event
        }
    }

    private func stopMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

struct LayoutDetailEmpty: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 10) {
            Text("No layout selected. Save your current Dock to create the first one.")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                NSApplication.shared.activate()
                openWindow(id: "save-layout")
            } label: {
                Text("Save Current Dock…")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(.tint, in: .capsule)
            .foregroundStyle(.white)
            .pointerStyle(.link)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
