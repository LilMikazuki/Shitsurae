import Foundation

/// Единственная точка, через которую Shitsurae меняет Dock.
/// Держит правило спеки: не смог прочитать — не имеешь права писать.
public struct DockEngine: Sendable {
    private let store: DockPreferenceStore
    private let backup: DockBackup
    private let restarter: DockRestarting

    public init(store: DockPreferenceStore, backup: DockBackup, restarter: DockRestarting) {
        self.store = store
        self.backup = backup
        self.restarter = restarter
    }

    /// Боевая сборка: настоящий домен, бэкап в Application Support, настоящий Dock.
    public static func live() -> DockEngine {
        DockEngine(
            store: CFPreferencesDockStore(),
            backup: DockBackup(directory: DockBackup.defaultDirectory),
            restarter: DockRestarter()
        )
    }

    public func read() throws -> DockState {
        try DockReader(store: store).read()
    }

    /// Порядок шагов важен и менять его нельзя.
    public func apply(_ state: DockState) throws {
        // 1. Убеждаемся, что домен нам понятен. Бросит — дальше не идём.
        _ = try read()
        // 2. Страховка до первой в жизни записи.
        try backup.createIfNeeded()
        // 3. Запись. Бросит — Dock не перезапускаем: применять нечего,
        // а моргнувшая панель соврала бы, что пресет применён.
        try DockWriter(store: store).write(state)
        // 4. Применение. Бросит здесь — уже поздно откатываться: домен уже
        // записан, бэкап уже есть. Это осознанно: честный отчёт — «записано,
        // но не применено», а не тишина, поэтому ошибку не глотаем и даём
        // ей всплыть наружу как есть.
        try restarter.restart()
    }
}
