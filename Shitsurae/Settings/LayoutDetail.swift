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

    private var isRecording: Bool {
        model.shortcuts.recordingID == layout.id
    }

    private var hotkeyTitle: String {
        guard isRecording else { return "Hotkey" }
        return model.shortcuts.hint ?? ShortcutCapture.recordingHint
    }

    private var pillBackground: AnyShapeStyle {
        if isRecording {
            return AnyShapeStyle(.tint)
        }
        if model.shortcuts.label(for: layout.id) == nil {
            return AnyShapeStyle(.clear)
        }
        return AnyShapeStyle(.quaternary)
    }

    private var pillForeground: AnyShapeStyle {
        if isRecording {
            return AnyShapeStyle(.white)
        }
        if model.shortcuts.label(for: layout.id) == nil {
            return AnyShapeStyle(.tertiary)
        }
        return AnyShapeStyle(.primary)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            summary
            Spacer(minLength: 0)
            DockStrip(model: model, layout: layout, icons: icons)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
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

    private var summary: some View {
        VStack(spacing: 7) {
            Text(layout.name)
                .font(.system(size: 26, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(AppModel.lastUsedLabel(layout.lastUsedAt))
            }
            .font(.system(size: 13.5))
            .foregroundStyle(.secondary)

            applyButton
                .padding(.top, 6)

            controls
                .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var applyButton: some View {
        Button {
            Task {
                await model.apply(id: layout.id)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(
                        isApplied ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white)
                    )
                Text(isApplied ? "Applied" : "Apply")
            }
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            isApplied ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.tint),
            in: .capsule
        )
        .foregroundStyle(isApplied ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
        .disabled(isApplied || model.isChangingDock)
        .pointerStyle(isApplied ? .default : .link)
        .help(isApplied ? "This layout is already in your Dock" : "Apply this layout to your Dock")
    }

    private var controls: some View {
        VStack(spacing: 0) {
            controlRow(
                title: hotkeyTitle,
                titleIsError: model.shortcuts.hintIsError,
                caption: nil
            ) {
                hotkeyPill
            }

            Divider()

            controlRow(
                title: "Auto-Quit Apps",
                icon: "power",
                caption: "Quits apps outside the layout you apply, for every layout"
            ) {
                Toggle("Auto-Quit Apps", isOn: $model.quitsOtherApps)
                    .toggleStyle(.capsuleSwitch)
                    .labelsHidden()
                    .help("Applies to every layout")
            }
        }
        .frame(width: 385)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }

    private func controlRow(
        title: String,
        titleIsError: Bool = false,
        icon: String? = nil,
        caption: String?,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.system(size: 13.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(
                            titleIsError ? AnyShapeStyle(.red) : AnyShapeStyle(.primary)
                        )
                }
                if let caption {
                    Text(caption)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private var hotkeyPill: some View {
        Button {
            model.selectedLayoutID = layout.id
            model.shortcuts.start(layout.id)
        } label: {
            Text(model.shortcuts.label(for: layout.id) ?? "Record")
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .background(pillBackground, in: .rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.separator, lineWidth: isRecording ? 0 : 0.5)
        )
        .foregroundStyle(pillForeground)
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
