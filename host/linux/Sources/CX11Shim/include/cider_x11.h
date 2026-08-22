/*
 * cider_x11 -- a flat C surface over the parts of Xlib the Linux backend uses.
 *
 * Xlib's API is heavy on macros and on structures that Swift's C importer models
 * awkwardly. Rather than spread that awkwardness through Swift code, this shim
 * exposes exactly the operations `CiderHost.HostWindow` needs: open a window,
 * copy a framebuffer to it, drain input, close. It holds no policy -- every
 * decision about what an event *means* is made in Swift.
 */

#ifndef CIDER_X11_H
#define CIDER_X11_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct cider_x11_window cider_x11_window;

enum cider_x11_event_kind {
    CIDER_X11_EVENT_NONE = 0,
    CIDER_X11_EVENT_POINTER_DOWN = 1,
    CIDER_X11_EVENT_POINTER_MOVE = 2,
    CIDER_X11_EVENT_POINTER_UP = 3,
    CIDER_X11_EVENT_POINTER_EXIT = 4,
    CIDER_X11_EVENT_REDRAW = 5,
    CIDER_X11_EVENT_RESIZE = 6,
    CIDER_X11_EVENT_CLOSE = 7
};

typedef struct {
    int kind;
    /* Pointer position in device pixels, window-relative. */
    int x;
    int y;
    /* X11 button number: 1 primary, 3 secondary. */
    int button;
    /* Populated for CIDER_X11_EVENT_RESIZE. */
    int width;
    int height;
} cider_x11_event;

/*
 * Opens a window of the given size in device pixels.
 *
 * Returns NULL on failure and writes a human-readable reason into `error`
 * (always NUL-terminated when `error_capacity > 0`). The reason is written for
 * a developer, not a log parser: the Swift side wraps it in a Diagnostic that
 * supplies the remedy.
 */
cider_x11_window *cider_x11_window_open(const char *title,
                                        int width,
                                        int height,
                                        char *error,
                                        size_t error_capacity);

void cider_x11_window_close(cider_x11_window *window);

int cider_x11_window_width(const cider_x11_window *window);
int cider_x11_window_height(const cider_x11_window *window);

/*
 * Copies `pixels` (0xAARRGGBB words, row-major, no row padding) to the window
 * and flushes.
 *
 * When the framebuffer is smaller than the window it is centred and the
 * remaining area is painted with the letterbox colour; when it is larger it is
 * cropped. The shim never scales -- a scaled presentation would make what the
 * developer sees differ from what a screenshot test captures.
 *
 * Returns 0 on success, non-zero on failure.
 */
int cider_x11_window_present(cider_x11_window *window,
                             const uint32_t *pixels,
                             int width,
                             int height);

/*
 * Removes one pending event, or reports CIDER_X11_EVENT_NONE when the queue is
 * empty. Never blocks.
 *
 * Returns 1 when `out` was filled with a real event, 0 when the queue was empty.
 */
int cider_x11_window_poll_event(cider_x11_window *window, cider_x11_event *out);

/*
 * Reports whether an X display can be opened at all, for `cider doctor`.
 * Returns 1 when a connection succeeded (it is closed again immediately), 0
 * otherwise, with the reason written to `error`.
 */
int cider_x11_probe_display(char *error, size_t error_capacity);

#ifdef __cplusplus
}
#endif

#endif /* CIDER_X11_H */
