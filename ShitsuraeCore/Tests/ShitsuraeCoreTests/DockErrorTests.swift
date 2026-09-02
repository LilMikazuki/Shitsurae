@testable import ShitsuraeCore
import Testing

@Test func theEngineErrorNamesItsCause() {
    #expect("\(DockError.read(.wrongType(key: "tilesize", expected: "Number")))"
        == "\(DockReadError.wrongType(key: "tilesize", expected: "Number"))")
    #expect("\(DockError.write(.synchronizeFailed))" == "\(DockWriteError.synchronizeFailed)")
    #expect("\(DockError.restart(.terminateRefused))" == "\(DockRestartError.terminateRefused)")
}
