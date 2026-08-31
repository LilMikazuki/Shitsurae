import CoreGraphics

/// Where a dragged tile would land, and how its neighbours make room.
///
/// Pure arithmetic, kept out of the view so it can be tested: the same values
/// drive the live preview and the reorder that follows, and the two must not
/// be able to disagree.
public struct TileDrag: Equatable, Sendable {
    public let from: Int
    public let count: Int
    public let step: CGFloat
    public let distance: CGFloat

    public init(from: Int, count: Int, step: CGFloat, distance: CGFloat) {
        self.from = from
        self.count = count
        self.step = step
        self.distance = distance
    }

    public var target: Int? {
        guard count > 0, step > 0, from >= 0, from < count else { return nil }
        let moved = from + Int((distance / step).rounded())
        let clamped = max(0, min(count - 1, moved))
        return clamped == from ? nil : clamped
    }

    /// How far the tile at `index` steps aside while the drag is live.
    public func offset(forTileAt index: Int) -> CGFloat {
        guard index != from, let target else { return 0 }
        if from < target, index > from, index <= target {
            return -step
        }
        if from > target, index >= target, index < from {
            return step
        }
        return 0
    }
}
