//  Cider's touch abstraction, and the translation from host pointer events.
//
//  On Linux the only pointer is a mouse, so it would be shorter to hand button
//  presses straight to hit testing. The indirection exists because a touch has
//  properties a mouse click does not -- an identifier, a phase that can be
//  cancelled by the system, and no notion of hovering -- and code that hit-tests
//  against clicks acquires assumptions that a real touchscreen then breaks.
//
//  Translating once, here, means the rest of the runtime has only ever seen
//  touches. See docs/adr/0002-linux-windowing-backend.md.

import CiderCore
import CiderHost

public enum TouchPhase: String, Sendable, Equatable {
    case began
    case moved
    case ended

    /// The touch was interrupted by something other than the user lifting: the
    /// pointer left the window, or the application was backgrounded. No action
    /// fires.
    case cancelled
}

/// A single contact, in logical points relative to the device's screen.
public struct Touch: Equatable, Sendable {
    /// Distinguishes contacts. Always 0 while a mouse is the only pointer; the
    /// field exists so multi-touch does not change this type.
    public var identifier: Int
    public var location: Point
    public var phase: TouchPhase

    public init(identifier: Int = 0, location: Point, phase: TouchPhase) {
        self.identifier = identifier
        self.location = location
        self.phase = phase
    }
}

/// Converts host events into touches.
///
/// The translator owns the device-pixel-to-point conversion, including the
/// offset introduced when a backend letterboxes a framebuffer inside a larger
/// window. Getting that wrong makes every tap land slightly off, which is
/// exactly the kind of bug that is invisible until someone measures it -- so it
/// lives in one place with one test.
struct PointerTranslator {
    /// Device pixels per logical point.
    var scale: Double

    /// Size of the presented framebuffer, in device pixels.
    var surfacePixelWidth: Int
    var surfacePixelHeight: Int

    /// Size of the host window, in device pixels.
    var windowPixelWidth: Int
    var windowPixelHeight: Int

    /// Translates one host event, or returns nil when it carries no touch.
    func touch(for event: HostEvent) -> Touch? {
        switch event {
        case .pointerDown(let location, let button):
            // Cider models one finger. A secondary click is not a second finger,
            // so it is dropped rather than turned into a tap the user did not make.
            guard button == .primary else { return nil }
            return Touch(location: convert(location), phase: .began)

        case .pointerMove(let location):
            return Touch(location: convert(location), phase: .moved)

        case .pointerUp(let location, let button):
            guard button == .primary else { return nil }
            return Touch(location: convert(location), phase: .ended)

        case .pointerExit:
            // There is no position to report: the pointer is gone. The runtime
            // only needs to know the touch died.
            return Touch(location: .zero, phase: .cancelled)

        case .redrawRequested, .resized, .closeRequested:
            return nil
        }
    }

    /// Window pixels to device-screen points.
    func convert(_ windowLocation: Point) -> Point {
        let offsetX = Double(windowPixelWidth - surfacePixelWidth) / 2
        let offsetY = Double(windowPixelHeight - surfacePixelHeight) / 2
        return Point(
            x: (windowLocation.x - offsetX) / scale,
            y: (windowLocation.y - offsetY) / scale
        )
    }
}
