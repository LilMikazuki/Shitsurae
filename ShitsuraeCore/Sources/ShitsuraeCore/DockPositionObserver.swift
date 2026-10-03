import Foundation

public final class DockPositionObserver: NSObject {
    private let defaults: UserDefaults
    private let onChange: @Sendable () -> Void

    public convenience init?(onChange: @escaping @Sendable () -> Void) {
        self.init(domain: DockKey.domain, onChange: onChange)
    }

    init?(domain: String, onChange: @escaping @Sendable () -> Void) {
        guard let defaults = UserDefaults(suiteName: domain) else { return nil }
        self.defaults = defaults
        self.onChange = onChange
        super.init()
        defaults.addObserver(self, forKeyPath: DockKey.orientation, options: [], context: nil)
    }

    deinit {
        defaults.removeObserver(self, forKeyPath: DockKey.orientation)
    }

    override public func observeValue(
        forKeyPath _: String?,
        of _: Any?,
        change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        onChange()
    }
}
