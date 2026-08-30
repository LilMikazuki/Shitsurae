/// Имена ключей домена `com.apple.dock`. Больше нигде строковых литералов ключей быть не должно.
public enum DockKey {
    /// Имя домена настроек Dock.
    ///
    /// Живёт здесь, а не в `CFPreferencesDockStore`, по требованию компилятора:
    /// публичное значение по умолчанию не может ссылаться на internal-объявление,
    /// а `DockBackup.init(directory:domain:)` публичен и берёт отсюда дефолт.
    ///
    /// Это НЕ то же самое, что `DockRestarter.bundleIdentifier`: macOS
    /// использует одну строку и для домена настроек, и для bundle id процесса
    /// по соглашению, а не по гарантии. Константы намеренно разные.
    public static let domain = "com.apple.dock"

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
        apps, tilesize, magnification, largesize, autohide, orientation, showRecents
    ]
}
