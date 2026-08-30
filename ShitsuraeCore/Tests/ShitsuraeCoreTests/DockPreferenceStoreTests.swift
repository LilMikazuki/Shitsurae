import Foundation
@testable import ShitsuraeCore
import Testing

@Test func сторВПамятиОтдаётЗаписанное() {
    let store = InMemoryDockStore(["tilesize": 48.0])
    #expect(store.value(forKey: "tilesize") as? Double == 48.0)
    #expect(store.value(forKey: "autohide") == nil)
}

@Test func сторВПамятиПишетИУдаляет() {
    let store = InMemoryDockStore([:])
    store.setValue(true, forKey: "autohide")
    #expect(store.value(forKey: "autohide") as? Bool == true)
    #expect(store.snapshot.count == 1)

    store.setValue(nil, forKey: "autohide")
    #expect(store.value(forKey: "autohide") == nil)
    #expect(store.snapshot["autohide"] == nil)
}

@Test func боевойСторЧитаетЖивойДомен() {
    let store = CFPreferencesDockStore()
    #expect(DockKey.domain == "com.apple.dock")
    #expect(store.value(forKey: DockKey.apps) != nil)
}

/// Тест существует ради компиляции: если стор перестанет быть `Sendable`,
/// этот файл не соберётся, и мы узнаем об этом здесь, а не в приложении.
@Test func сторПересекаетГраницуАктора() async {
    let store = InMemoryDockStore([DockKey.autohide: true])
    let task = Task.detached {
        store.setValue(false, forKey: DockKey.autohide)
        return store.value(forKey: DockKey.autohide) as? Bool
    }
    #expect(await task.value == false)
}

@Test func одновременнаяЗаписьНеРоняетСтор() async {
    let store = InMemoryDockStore([:])
    await withTaskGroup(of: Void.self) { group in
        for index in 0 ..< 50 {
            group.addTask { store.setValue(index, forKey: "key-\(index)") }
        }
    }
    #expect(store.snapshot.count == 50)
}
