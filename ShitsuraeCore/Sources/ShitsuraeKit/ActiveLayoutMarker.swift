import Foundation

public struct ActiveLayoutMarker: Sendable {
    private nonisolated(unsafe) let defaults: UserDefaults

    private static let key = "lastAppliedLayoutID"
    private static let legacyKey = "lastAppliedPresetID"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var id: UUID? {
        get {
            let stored = defaults.string(forKey: Self.key)
                ?? defaults.string(forKey: Self.legacyKey)
            return stored.flatMap(UUID.init(uuidString:))
        }
        nonmutating set {
            defaults.set(newValue?.uuidString, forKey: Self.key)
            defaults.removeObject(forKey: Self.legacyKey)
        }
    }
}
