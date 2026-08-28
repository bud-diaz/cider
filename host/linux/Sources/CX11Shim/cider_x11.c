#include "cider_x11.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Painted around a framebuffer smaller than the window. Chosen to be obviously
   "not the application" so a size mismatch is visible rather than subtle. */
#define CIDER_X11_LETTERBOX 0x00101014u

struct cider_x11_window {
    Display *display;
    Window window;
    GC gc;
    Atom wm_delete_window;
    int screen;
    int depth;
    int width;
    int height;

    /* Scratch buffer handed to XImage. Sized to the window, reallocated on
       resize. XImage borrows it; we own it. */
    uint32_t *surface;
    size_t surface_capacity;
    XImage *image;
};

static void set_error(char *error, size_t capacity, const char *message) {
    if (error == NULL || capacity == 0) {
        return;
    }
    strncpy(error, message, capacity - 1);
    error[capacity - 1] = '\0';
}

/* Ensures `surface`/`image` describe a w*h ARGB buffer. Returns 0 on success. */
static int ensure_surface(struct cider_x11_window *w, int width, int height) {
    size_t needed = (size_t)width * (size_t)height;
    if (needed == 0) {
        return 1;
    }

    if (w->image != NULL && w->image->width == width && w->image->height == height) {
        return 0;
    }

    if (w->surface_capacity < needed) {
        uint32_t *grown = realloc(w->surface, needed * sizeof(uint32_t));
        if (grown == NULL) {
            return 1;
        }
        w->surface = grown;
        w->surface_capacity = needed;
    }

    if (w->image != NULL) {
        /* The XImage does not own `surface`, so detach before destroying it;
           otherwise XDestroyImage frees a buffer we are still using. */
        w->image->data = NULL;
        XDestroyImage(w->image);
        w->image = NULL;
    }

    w->image = XCreateImage(w->display,
                            DefaultVisual(w->display, w->screen),
                            (unsigned int)w->depth,
                            ZPixmap,
                            0,
                            (char *)w->surface,
                            (unsigned int)width,
                            (unsigned int)height,
                            32,
                            0);
    if (w->image == NULL) {
        return 1;
    }
    return 0;
}

cider_x11_window *cider_x11_window_open(const char *title,
                                        int width,
                                        int height,
                                        char *error,
                                        size_t error_capacity) {
    if (width <= 0 || height <= 0) {
        set_error(error, error_capacity, "window size must be positive");
        return NULL;
    }

    Display *display = XOpenDisplay(NULL);
    if (display == NULL) {
        const char *name = getenv("DISPLAY");
        if (name == NULL || name[0] == '\0') {
            set_error(error, error_capacity, "DISPLAY is not set");
        } else {
            set_error(error, error_capacity, "could not open the X display named by DISPLAY");
        }
        return NULL;
    }

    int screen = DefaultScreen(display);
    int depth = DefaultDepth(display, screen);
    if (depth != 24 && depth != 32) {
        char message[128];
        snprintf(message, sizeof(message),
                 "unsupported X visual depth %d; Cider needs a 24- or 32-bit TrueColor visual",
                 depth);
        set_error(error, error_capacity, message);
        XCloseDisplay(display);
        return NULL;
    }

    Visual *visual = DefaultVisual(display, screen);
    if (visual->class != TrueColor) {
        set_error(error, error_capacity,
                  "the default X visual is not TrueColor; Cider needs a TrueColor visual");
        XCloseDisplay(display);
        return NULL;
    }

    struct cider_x11_window *w = calloc(1, sizeof(struct cider_x11_window));
    if (w == NULL) {
        set_error(error, error_capacity, "out of memory");
        XCloseDisplay(display);
        return NULL;
    }

    w->display = display;
    w->screen = screen;
    w->depth = depth;
    w->width = width;
    w->height = height;

    w->window = XCreateSimpleWindow(display,
                                    RootWindow(display, screen),
                                    0, 0,
                                    (unsigned int)width, (unsigned int)height,
                                    0,
                                    BlackPixel(display, screen),
                                    BlackPixel(display, screen));

    XStoreName(display, w->window, title != NULL ? title : "Cider");

    /* Ask the window manager for exactly this size. A WM is free to refuse, so
       present() still handles a mismatch. */
    XSizeHints *hints = XAllocSizeHints();
    if (hints != NULL) {
        hints->flags = PMinSize | PMaxSize;
        hints->min_width = hints->max_width = width;
        hints->min_height = hints->max_height = height;
        XSetWMNormalHints(display, w->window, hints);
        XFree(hints);
    }

    XSelectInput(display, w->window,
                 ExposureMask | ButtonPressMask | ButtonReleaseMask |
                 PointerMotionMask | LeaveWindowMask | StructureNotifyMask |
                 KeyPressMask | KeyReleaseMask);

    w->wm_delete_window = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, w->window, &w->wm_delete_window, 1);

    w->gc = XCreateGC(display, w->window, 0, NULL);
    if (w->gc == NULL) {
        set_error(error, error_capacity, "could not create an X graphics context");
        XDestroyWindow(display, w->window);
        XCloseDisplay(display);
        free(w);
        return NULL;
    }

    if (ensure_surface(w, width, height) != 0) {
        set_error(error, error_capacity, "could not allocate the window framebuffer");
        cider_x11_window_close(w);
        return NULL;
    }

    XMapWindow(display, w->window);
    XFlush(display);
    return w;
}

void cider_x11_window_close(cider_x11_window *window) {
    if (window == NULL) {
        return;
    }
    if (window->image != NULL) {
        window->image->data = NULL;
        XDestroyImage(window->image);
        window->image = NULL;
    }
    free(window->surface);
    window->surface = NULL;

    if (window->display != NULL) {
        if (window->gc != NULL) {
            XFreeGC(window->display, window->gc);
        }
        if (window->window != 0) {
            XDestroyWindow(window->display, window->window);
            window->window = 0;
        }
        XCloseDisplay(window->display);
        window->display = NULL;
    }
    free(window);
}

int cider_x11_window_width(const cider_x11_window *window) {
    return window != NULL ? window->width : 0;
}

int cider_x11_window_height(const cider_x11_window *window) {
    return window != NULL ? window->height : 0;
}

int cider_x11_window_present(cider_x11_window *window,
                             const uint32_t *pixels,
                             int width,
                             int height) {
    if (window == NULL || pixels == NULL || width <= 0 || height <= 0) {
        return 1;
    }
    if (ensure_surface(window, window->width, window->height) != 0) {
        return 1;
    }

    const int dest_width = window->width;
    const int dest_height = window->height;

    /* Centre the framebuffer; crop it when it is larger than the window. */
    const int offset_x = (dest_width - width) / 2;
    const int offset_y = (dest_height - height) / 2;

    for (int y = 0; y < dest_height; ++y) {
        uint32_t *dest_row = window->surface + (size_t)y * (size_t)dest_width;
        const int source_y = y - offset_y;
        if (source_y < 0 || source_y >= height) {
            for (int x = 0; x < dest_width; ++x) {
                dest_row[x] = CIDER_X11_LETTERBOX;
            }
            continue;
        }
        const uint32_t *source_row = pixels + (size_t)source_y * (size_t)width;
        for (int x = 0; x < dest_width; ++x) {
            const int source_x = x - offset_x;
            dest_row[x] = (source_x >= 0 && source_x < width)
                ? source_row[source_x]
                : CIDER_X11_LETTERBOX;
        }
    }

    window->image->data = (char *)window->surface;
    XPutImage(window->display, window->window, window->gc, window->image,
              0, 0, 0, 0,
              (unsigned int)dest_width, (unsigned int)dest_height);
    XFlush(window->display);
    return 0;
}

int cider_x11_window_poll_event(cider_x11_window *window, cider_x11_event *out) {
    if (window == NULL || out == NULL) {
        return 0;
    }
    memset(out, 0, sizeof(*out));

    while (XPending(window->display) > 0) {
        XEvent event;
        XNextEvent(window->display, &event);

        switch (event.type) {
        case ButtonPress:
            /* Buttons 4-7 are scroll wheel notches in the X11 encoding, not
               pointer buttons: 4/5 vertical, 6/7 horizontal. There is no
               sub-notch resolution to report, so each press is exactly one
               unit of delta in the matching direction. */
            if (event.xbutton.button >= 4 && event.xbutton.button <= 7) {
                out->kind = CIDER_X11_EVENT_SCROLL;
                out->x = event.xbutton.x;
                out->y = event.xbutton.y;
                switch (event.xbutton.button) {
                case 4: out->scroll_delta_y = -1; break;
                case 5: out->scroll_delta_y = 1; break;
                case 6: out->scroll_delta_x = -1; break;
                case 7: out->scroll_delta_x = 1; break;
                }
                return 1;
            }
            out->kind = CIDER_X11_EVENT_POINTER_DOWN;
            out->x = event.xbutton.x;
            out->y = event.xbutton.y;
            out->button = (int)event.xbutton.button;
            return 1;

        case ButtonRelease:
            /* The release half of a wheel notch carries nothing Cider uses;
               only the press above becomes a scroll event. */
            if (event.xbutton.button >= 4 && event.xbutton.button <= 7) {
                continue;
            }
            out->kind = CIDER_X11_EVENT_POINTER_UP;
            out->x = event.xbutton.x;
            out->y = event.xbutton.y;
            out->button = (int)event.xbutton.button;
            return 1;

        case KeyPress: {
            KeySym key_sym = NoSymbol;
            char text[sizeof(out->text)];
            int text_length = XLookupString(&event.xkey, text, (int)sizeof(text), &key_sym, NULL);
            out->key_sym = key_sym;
            if (text_length > 0) {
                if (text_length > (int)sizeof(out->text)) {
                    text_length = (int)sizeof(out->text);
                }
                out->kind = CIDER_X11_EVENT_TEXT_INPUT;
                memcpy(out->text, text, (size_t)text_length);
                out->text_length = text_length;
            } else {
                out->kind = CIDER_X11_EVENT_KEY_DOWN;
            }
            return 1;
        }

        case KeyRelease:
            out->kind = CIDER_X11_EVENT_KEY_UP;
            out->key_sym = XLookupKeysym(&event.xkey, 0);
            return 1;

        case MotionNotify:
            out->kind = CIDER_X11_EVENT_POINTER_MOVE;
            out->x = event.xmotion.x;
            out->y = event.xmotion.y;
            return 1;

        case LeaveNotify:
            out->kind = CIDER_X11_EVENT_POINTER_EXIT;
            return 1;

        case Expose:
            /* Only the last rectangle of a burst matters: Cider redraws the
               whole surface either way. */
            if (event.xexpose.count > 0) {
                continue;
            }
            out->kind = CIDER_X11_EVENT_REDRAW;
            return 1;

        case DestroyNotify:
            /* The window went away without a WM_DELETE_WINDOW round trip -- a
               tool destroyed it, or the session ended. Report it as a close so
               the runtime shuts down instead of idling with nothing on screen.

               Forget the id as well: destroying it again during teardown would
               raise a BadWindow that Xlib prints over whatever Cider was saying
               about the shutdown. */
            window->window = 0;
            out->kind = CIDER_X11_EVENT_CLOSE;
            return 1;

        case ConfigureNotify:
            if (event.xconfigure.width == window->width &&
                event.xconfigure.height == window->height) {
                continue;
            }
            window->width = event.xconfigure.width;
            window->height = event.xconfigure.height;
            out->kind = CIDER_X11_EVENT_RESIZE;
            out->width = window->width;
            out->height = window->height;
            return 1;

        case ClientMessage:
            if ((Atom)event.xclient.data.l[0] == window->wm_delete_window) {
                out->kind = CIDER_X11_EVENT_CLOSE;
                return 1;
            }
            continue;

        default:
            continue;
        }
    }

    return 0;
}

int cider_x11_probe_display(char *error, size_t error_capacity) {
    Display *display = XOpenDisplay(NULL);
    if (display == NULL) {
        const char *name = getenv("DISPLAY");
        if (name == NULL || name[0] == '\0') {
            set_error(error, error_capacity, "DISPLAY is not set");
        } else {
            set_error(error, error_capacity, "could not connect to the X display");
        }
        return 0;
    }
    XCloseDisplay(display);
    return 1;
}
