import Foundation

/// Единственная точка, через которую Shitsurae меняет Dock.
/// Держит правило спеки: не смог прочитать — не имеешь права писать.
public struct DockEngine: Sendable {
    private let store: DockPreferenceStore
    private let backup: DockBackup
    private let restarter: DockRestarting

    init(store: DockPreferenceStore, backup: DockBackup, restarter: DockRestarting) {
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

    /// Что случилось бы при `apply`, без единой записи в настоящий домен.
    ///
    /// Песочница засевается текущими значениями наших ключей, а не пустотой:
    /// `DockWriter` намеренно не пишет `nil`-настройки, потому что отсутствие
    /// значения означает «оставить как есть». На пустой песочнице такая
    /// настройка выглядела бы сброшенной в дефолт — предпросмотр врал бы ровно
    /// там, где он нужнее всего.
    ///
    /// Шаг бэкапа предпросмотр не выполняет и не проверяет: машина, на которой
    /// каталог бэкапа недоступен на запись, получит чистый предпросмотр и
    /// упавший `apply`, а не наоборот.
    public func preview(_ state: DockState) throws -> DockState {
        // Тот же гейт, что и в `apply`: не прочитал — не пишу. Без него
        // предпросмотр отчитался бы об успехе там, где настоящее применение
        // отказалось бы писать.
        _ = try read()

        var seed: [String: Any] = [:]
        for key in DockKey.all {
            if let value = store.value(forKey: key) {
                seed[key] = value
            }
        }
        let sandbox = InMemoryDockStore(seed)
        try DockWriter(store: sandbox).write(state)
        return try DockReader(store: sandbox).read()
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
