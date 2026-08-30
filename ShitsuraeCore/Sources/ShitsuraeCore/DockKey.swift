/// Имена ключей домена `com.apple.dock`. Больше нигде строковых литералов ключей быть не должно.
public enum DockKey {
    public static let apps = "persistent-apps"
    public static let tilesize = "tilesize"
    public static let magnification = "magnification"
    public static let largesize = "largesize"
    public static let autohide = "autohide"
    public static let orientation = "orientation"
    public static let showRecents = "show-recents"

    /// Все семь ключей разом — для мест, которым нужен полный набор,
    /// а не конкретный ключ (например, снятие снимка домена целиком).
    public static let all: [String] = [
        apps, tilesize, magnification, largesize, autohide, orientation, showRecents,
    ]
}
