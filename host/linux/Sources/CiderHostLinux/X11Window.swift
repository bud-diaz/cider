//  HostWindow over the X11 shim.

import CiderCore
import CiderHost
import CX11Shim

final class X11Window: HostWindow {
    private var handle: OpaquePointer?

    init(_ configuration: WindowConfiguration) throws {
        var error = [CChar](repeating: 0, count: 256)
        let opened = configuration.title.withCString { title in
            error.withUnsafeMutableBufferPointer { buffer in
                cider_x11_window_open(
                    title,
                    Int32(configuration.pixelWidth),
                    Int32(configuration.pixelHeight),
                    buffer.baseAddress,
                    buffer.count
                )
            }
        }

        guard let opened else {
            throw Diagnostic(
                code: "CID0101",
                summary: "could not open a window",
                reason: """
                    Cider's Linux backend asked X11 for a \
                    \(configuration.pixelWidth)x\(configuration.pixelHeight) window and was \
                    refused: \(cString: error).
                    """,
                remedy: """
                    Check that a display server is running and that DISPLAY points at it:

                        echo $DISPLAY
                        cider doctor
                    """
            )
        }
        self.handle = opened
    }

    deinit {
        close()
    }

    var pixelWidth: Int {
        guard let handle else { return 0 }
        return Int(cider_x11_window_width(handle))
    }

    var pixelHeight: Int {
        guard let handle else { return 0 }
        return Int(cider_x11_window_height(handle))
    }

    func present(_ canvas: Canvas) throws {
        guard let handle else { return }
        let status = canvas.withUnsafePixels { pixels -> Int32 in
            guard let base = pixels.baseAddress else { return 1 }
            return cider_x11_window_present(handle, base, Int32(canvas.width), Int32(canvas.height))
        }
        if status != 0 {
            throw Diagnostic(
                code: "CID0102",
                summary: "could not present a frame",
                reason: "The X11 backend failed to copy the framebuffer to the window.",
                remedy: "Re-run with --log-level debug and file an issue with the output."
            )
        }
    }

    func pollEvents() -> [HostEvent] {
        guard let handle else { return [] }
        var events: [HostEvent] = []
        var raw = cider_x11_event()

        // Drain fully: X delivers motion in bursts, and leaving events queued
        // would show up as input lag on the next frame.
        while cider_x11_window_poll_event(handle, &raw) == 1 {
            if let event = Self.translate(raw) {
                events.append(event)
            }
        }
        return events
    }

    func close() {
        guard let handle else { return }
        cider_x11_window_close(handle)
        self.handle = nil
    }

    private static func translate(_ raw: cider_x11_event) -> HostEvent? {
        let location = Point(x: Double(raw.x), y: Double(raw.y))
        switch UInt32(raw.kind) {
        case CIDER_X11_EVENT_POINTER_DOWN.rawValue:
            return .pointerDown(location: location, button: button(raw.button))
        case CIDER_X11_EVENT_POINTER_MOVE.rawValue:
            return .pointerMove(location: location)
        case CIDER_X11_EVENT_POINTER_UP.rawValue:
            return .pointerUp(location: location, button: button(raw.button))
        case CIDER_X11_EVENT_POINTER_EXIT.rawValue:
            return .pointerExit
        case CIDER_X11_EVENT_REDRAW.rawValue:
            return .redrawRequested
        case CIDER_X11_EVENT_RESIZE.rawValue:
            return .resized(width: Int(raw.width), height: Int(raw.height))
        case CIDER_X11_EVENT_CLOSE.rawValue:
            return .closeRequested
        default:
            return nil
        }
    }

    private static func button(_ raw: Int32) -> PointerButton {
        switch raw {
        case 1: return .primary
        case 3: return .secondary
        default: return .other(Int(raw))
        }
    }
}
