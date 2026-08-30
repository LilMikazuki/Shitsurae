import Foundation
@testable import ShitsuraeCore
import Testing

@Test func выводПеречисляетПриложенияИНастройки() throws {
    let state = try DockReader(store: fixtureStore()).read()
    let text = DockStateFormatter.plainText(state)
    #expect(text.contains("Apps (4)"))
    #expect(text.contains("com.apple.apps.launcher"))
    #expect(text.contains("tilesize: 82.0"))
}

@Test func отсутствующиеНастройкиПомеченыКакDefault() throws {
    let state = try DockReader(store: fixtureStore()).read()
    let text = DockStateFormatter.plainText(state)
    #expect(text.contains("orientation: (default)"))
}

@Test func пустоеСостояниеНеЛомаетВывод() {
    let text = DockStateFormatter.plainText(DockState(apps: [], settings: DockSettings()))
    #expect(text.contains("Apps (0)"))
}
