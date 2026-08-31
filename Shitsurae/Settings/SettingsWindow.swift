import ShitsuraeKit
import SwiftUI

struct SettingsWindow: View {
    @Bindable var model: AppModel
    let launchAtLogin: any LaunchAtLoginControlling

    @State private var icons = AppIconLoader()
    @State private var showingGeneral = false

    var body: some View {
        NavigationSplitView {
            LayoutSidebar(model: model, showingGeneral: $showingGeneral)
                .navigationSplitViewColumnWidth(min: 210, ideal: 232, max: 300)
        } detail: {
            detail
        }
        .navigationTitle(showingGeneral ? "General" : "Shitsurae")
        .frame(minWidth: 720, minHeight: 500)
    }

    @ViewBuilder
    private var detail: some View {
        if showingGeneral {
            GeneralTab(launchAtLogin: launchAtLogin)
        } else if let layout = model.selectedLayout {
            LayoutDetail(model: model, layout: layout, icons: icons)
        } else {
            LayoutDetailEmpty()
        }
    }
}
