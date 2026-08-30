import AppKit
import Foundation

/// Перезапуск Dock вынесен за протокол, чтобы тесты не убивали настоящий Dock.
public protocol DockRestarting: Sendable {
    func restart() throws
}

/// Провал перезапуска Dock. К моменту, когда это бросается, домен уже
/// записан и бэкап уже существует — ошибка означает «записано, но не
/// применено», а не «ничего не произошло».
public enum DockRestartError: Error, Equatable {
    /// Процесс Dock не найден — терминировать нечего.
    case dockProcessNotFound
    /// Dock отказался завершиться.
    case terminateRefused
}

extension DockRestartError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dockProcessNotFound:
            "The Dock process could not be found, so it could not be restarted."
        case .terminateRefused:
            "The Dock process refused to terminate."
        }
    }
}

/// Публичного API у Dock нет: единственный способ применить изменения —
/// завершить демон, launchd поднимет его заново. Панель при этом моргнёт.
public final class DockRestarter: DockRestarting {
    /// Тот же самый идентификатор, что и `DockKey.domain`,
    /// но это отдельная константа: macOS использует одну строку и для домена
    /// настроек, и для bundle id процесса по соглашению, а не по гарантии.
    /// Если один когда-нибудь поменяют по причине, касающейся только
    /// настроек, другой не должен молча сломаться.
    private static let bundleIdentifier = "com.apple.dock"

    public init() {}

    public func restart() throws {
        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        )
        guard !apps.isEmpty else {
            throw DockRestartError.dockProcessNotFound
        }
        for app in apps {
            guard app.terminate() else {
                throw DockRestartError.terminateRefused
            }
        }
    }
}
