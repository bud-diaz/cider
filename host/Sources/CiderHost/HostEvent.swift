//  Raw input and window events, as a backend reports them.
//
//  These are deliberately *host* events, not Cider touches. The translation from
//  a pointer to Cider's touch abstraction happens in the runtime, so a future
//  backend that has a real touchscreen can emit richer events without every
//  intermediate layer changing shape. See docs/adr/0002.

import CiderCore

/// Which physical button a pointer event came from. Cider only acts on
/// `.primary` today; the others are carried so a backend never has to decide
/// what the runtime cares about.
public enum PointerButton: Sendable, Equatable {
    case primary
    case secondary
    case other(Int)
}

public enum HostEvent: Sendable, Equatable {
    /// A pointer went down inside the window. `location` is in device pixels
    /// with the origin at the window's top-left.
    case pointerDown(location: Point, button: PointerButton)

    /// A pointer moved. Reported whether or not a button is held; the runtime
    /// decides what constitutes a drag.
    case pointerMove(location: Point)

    case pointerUp(location: Point, button: PointerButton)

    /// The pointer left the window. The runtime cancels any in-flight touch,
    /// because a release outside the window will never arrive.
    case pointerExit

    /// The window contents were damaged and must be presented again.
    case redrawRequested

    /// The window was resized to the given device-pixel size.
    case resized(width: Int, height: Int)

    /// The user asked the window to close.
    case closeRequested
}
