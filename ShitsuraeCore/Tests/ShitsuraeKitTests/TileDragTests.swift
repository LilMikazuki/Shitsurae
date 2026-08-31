import CoreGraphics
import Foundation
@testable import ShitsuraeKit
import Testing

private func drag(from: Int, count: Int = 5, distance: CGFloat) -> TileDrag {
    TileDrag(from: from, count: count, step: 74, distance: distance)
}

@Test func aTileStaysPutUntilItPassesHalfOfItsNeighbour() {
    #expect(drag(from: 2, distance: 0).target == nil)
    #expect(drag(from: 2, distance: 36).target == nil, "just under half a step")
    #expect(drag(from: 2, distance: 37).target == 3, "half a step lands on the neighbour")
    #expect(drag(from: 2, distance: -37).target == 1)
}

@Test func aTileCannotBeDraggedOutOfTheStrip() {
    #expect(drag(from: 0, distance: -500).target == nil, "already first")
    #expect(drag(from: 4, distance: 500).target == nil, "already last")
    #expect(drag(from: 2, distance: -500).target == 0)
    #expect(drag(from: 2, distance: 500).target == 4)
}

@Test func neighboursStepAsideOnlyBetweenTheOldAndNewPlace() {
    let forward = drag(from: 1, distance: 148)
    #expect(forward.target == 3)
    #expect(forward.offset(forTileAt: 0) == 0)
    #expect(forward.offset(forTileAt: 1) == 0, "the dragged tile follows the cursor instead")
    #expect(forward.offset(forTileAt: 2) == -74)
    #expect(forward.offset(forTileAt: 3) == -74)
    #expect(forward.offset(forTileAt: 4) == 0)

    let backward = drag(from: 3, distance: -148)
    #expect(backward.target == 1)
    #expect(backward.offset(forTileAt: 0) == 0)
    #expect(backward.offset(forTileAt: 1) == 74)
    #expect(backward.offset(forTileAt: 2) == 74)
    #expect(backward.offset(forTileAt: 3) == 0)
}

@Test func nobodyMovesWhileTheTileIsStillOverItsOwnPlace() {
    let held = drag(from: 2, distance: 10)
    #expect(held.target == nil)
    for index in 0 ..< 5 {
        #expect(held.offset(forTileAt: index) == 0)
    }
}

@Test func anEmptyOrBrokenStripYieldsNoTarget() {
    #expect(TileDrag(from: 0, count: 0, step: 74, distance: 100).target == nil)
    #expect(TileDrag(from: 0, count: 3, step: 0, distance: 100).target == nil)
    #expect(TileDrag(from: 7, count: 3, step: 74, distance: 100).target == nil)
}
