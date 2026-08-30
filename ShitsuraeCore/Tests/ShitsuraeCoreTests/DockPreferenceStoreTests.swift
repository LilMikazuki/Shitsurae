import Foundation
import Testing
@testable import ShitsuraeCore

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
    #expect(CFPreferencesDockStore.domainName == "com.apple.dock")
    #expect(store.value(forKey: DockKey.apps) != nil)
}
