import AppKit
@testable import ShitsuraeKit
import Testing

@Test @MainActor func aMissingApplicationYieldsNil() {
    let loader = AppIconLoader()
    #expect(loader.icon(forAppAt: "/Applications/No Such App.app") == nil)
    #expect(loader.isPresent(at: "/Applications/No Such App.app") == false)
}

@Test @MainActor func anExistingApplicationYieldsAnIcon() {
    let loader = AppIconLoader()
    let finder = "/System/Library/CoreServices/Finder.app"
    #expect(loader.isPresent(at: finder))
    #expect(loader.icon(forAppAt: finder) != nil)
}

@Test @MainActor func askingTwiceReturnsTheSameObject() {
    let loader = AppIconLoader()
    let finder = "/System/Library/CoreServices/Finder.app"
    let first = loader.icon(forAppAt: finder)
    let second = loader.icon(forAppAt: finder)
    #expect(first === second)
}
