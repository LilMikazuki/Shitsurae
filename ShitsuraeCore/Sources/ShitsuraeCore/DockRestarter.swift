import AppKit
import Foundation

/// Перезапуск Dock вынесен за протокол, чтобы тесты не убивали настоящий Dock.
public protocol DockRestarting {
    func restart()
}

/// Публичного API у Dock нет: единственный способ применить изменения —
/// завершить демон, launchd поднимет его заново. Панель при этом моргнёт.
public final class DockRestarter: DockRestarting {
    public init() {}

    public func restart() {
        for app in NSRunningApplication.runningApplications(
            withBundleIdentifier: CFPreferencesDockStore.domainName) {
            app.terminate()
        }
    }
}
