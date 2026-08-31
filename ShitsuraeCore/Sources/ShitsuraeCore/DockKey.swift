public enum DockKey {
    public static let domain = "com.apple.dock"

    public static let apps = "persistent-apps"
    public static let tilesize = "tilesize"
    public static let magnification = "magnification"
    public static let largesize = "largesize"
    public static let autohide = "autohide"
    public static let orientation = "orientation"
    public static let showRecents = "show-recents"

    public static let all: [String] = [
        apps, tilesize, magnification, largesize, autohide, orientation, showRecents
    ]
}
