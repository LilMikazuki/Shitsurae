import AppKit
import ShitsuraeKit
import SwiftUI

struct SettingsWindow: View {
    let model: AppModel
    let launchAtLogin: any LaunchAtLoginControlling

    @Environment(\.controlActiveState) private var activeState
    @State private var icons = AppIconLoader()

    var body: some View {
        SplitLayout(model: model, launchAtLogin: launchAtLogin, icons: icons)
            .ignoresSafeArea()
            .frame(minWidth: 716, minHeight: 486)
            .background(WindowChrome())
            .onChange(of: activeState) { _, state in
                guard state == .key else { return }
                model.refreshFromDisk()
            }
    }
}

/// `NSSplitViewItem(sidebarWithViewController:)` is what carries the system's sidebar appearance —
/// the translucent material, the full-height layout under the title bar, collapsing, the standard
/// widths. Rebuilding that in SwiftUI is what this replaced, and it never matched.
private struct SplitLayout: NSViewControllerRepresentable {
    let model: AppModel
    let launchAtLogin: any LaunchAtLoginControlling
    let icons: AppIconLoader

    func makeNSViewController(context _: Context) -> NSSplitViewController {
        let controller = NSSplitViewController()

        let sidebar = NSHostingController(rootView: SidebarPane(model: model))
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 300
        controller.addSplitViewItem(sidebarItem)

        let detail = NSHostingController(
            rootView: DetailPane(model: model, launchAtLogin: launchAtLogin, icons: icons)
        )
        // The column reserves 66pt under the title bar and its empty toolbar. Nothing is drawn
        // there, so the pages take that space back and set their own top inset.
        detail.safeAreaRegions = []
        controller.addSplitViewItem(NSSplitViewItem(viewController: detail))

        return controller
    }

    func updateNSViewController(_: NSSplitViewController, context _: Context) {}
}

private struct SidebarPane: View {
    let model: AppModel

    var body: some View {
        LayoutSidebar(model: model)
            .scrollEdgeEffectHidden(true, for: .top)
    }
}

private struct DetailPane: View {
    let model: AppModel
    let launchAtLogin: any LaunchAtLoginControlling
    let icons: AppIconLoader

    var body: some View {
        Group {
            if model.page == .general {
                GeneralTab(launchAtLogin: launchAtLogin)
            } else if let layout = model.selectedLayout {
                LayoutDetail(model: model, layout: layout, icons: icons)
            } else {
                LayoutDetailEmpty()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectHidden(true, for: .top)
    }
}

/// The window-level separator style is documented to override every split item's preference, and it
/// is the only public lever over the line macOS 26 draws where the title bar meets a column.
private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ChromeView()
    }

    func updateNSView(_ view: NSView, context _: Context) {
        (view as? ChromeView)?.applyChrome()
    }
}

private final class ChromeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyChrome()
    }

    func applyChrome() {
        guard let window else { return }
        window.titlebarSeparatorStyle = .none
        // A sidebar only rises into the title bar when the window has a unified toolbar area to
        // rise into; without a toolbar AppKit lays it out 32pt below the top, full-height flag or
        // not.
        if window.toolbar == nil {
            window.toolbar = NSToolbar()
        }
        window.toolbarStyle = .unified
    }
}
