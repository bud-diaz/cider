//  Geometry primitives shared by layout, rendering, input and device profiles.
//
//  All values are in *logical points*. The conversion from points to physical
//  pixels happens once, in the rasterizer, using the device profile's scale.

/// A location in logical points.
public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)
}

/// A width/height pair in logical points. Negative extents are not meaningful
/// in a layout tree, so they are clamped at construction rather than tolerated
/// and then debugged later.
public struct Size: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public static let zero = Size(width: 0, height: 0)
}

/// An axis-aligned rectangle in logical points.
public struct Rect: Equatable, Sendable {
    public var origin: Point
    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: Point(x: x, y: y), size: Size(width: width, height: height))
    }

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var width: Double { size.width }
    public var height: Double { size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }

    /// Half-open containment: a point on the max edge is *outside*. This keeps
    /// adjacent rectangles from both claiming the same pointer event.
    public func contains(_ point: Point) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    public func offsetBy(dx: Double, dy: Double) -> Rect {
        Rect(x: minX + dx, y: minY + dy, width: width, height: height)
    }

    public func inset(by insets: EdgeInsets) -> Rect {
        Rect(
            x: minX + insets.left,
            y: minY + insets.top,
            width: width - insets.left - insets.right,
            height: height - insets.top - insets.bottom
        )
    }

    /// The overlapping region of `self` and `other`, or `nil` if they don't
    /// overlap. Used to intersect nested clip rects: a clip stack only ever
    /// shrinks what is visible, and this is the operation that shrinks it.
    public func intersection(_ other: Rect) -> Rect? {
        let x1 = max(minX, other.minX)
        let y1 = max(minY, other.minY)
        let x2 = min(maxX, other.maxX)
        let y2 = min(maxY, other.maxY)
        guard x1 < x2, y1 < y2 else { return nil }
        return Rect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }
}

/// Per-edge insets, used for safe areas and for padding inside a control.
public struct EdgeInsets: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public init(all value: Double) {
        self.init(top: value, left: value, bottom: value, right: value)
    }

    public init(horizontal: Double, vertical: Double) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    public static let zero = EdgeInsets(all: 0)

    public var horizontal: Double { left + right }
    public var vertical: Double { top + bottom }
}
