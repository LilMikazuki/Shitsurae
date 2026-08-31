import Foundation
import ServiceManagement

public protocol LaunchAtLoginControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ on: Bool) throws
}

public struct SMAppServiceLaunchAtLogin: LaunchAtLoginControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
