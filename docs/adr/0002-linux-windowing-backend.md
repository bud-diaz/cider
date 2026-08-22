# 0002. Linux windowing and rendering backend

## Status

Accepted — 2026-08-22. Applies to the Linux backend only; the Windows backend
will make its own decision within the same abstraction.

## Context

Cider needs a window on Linux, a way to get pixels into it, input events out of
it, and text rendered. `docs/03-technical-architecture.md` section 4 asks for a
spike before any library is frozen, and warns:

> No dependency should be chosen solely because it makes the first screenshot
> easy if it makes Windows support structurally painful.

The decision splits in two, and separating them is most of the work:

1. **Who owns the window and the input queue.**
2. **Who turns a UI tree into pixels.**

Conflating these is the trap. Every candidate framework — SDL, GTK, Qt — answers
both, and answering the second one for us is what causes the long-term problem:
if a backend draws, then "the same application" looks different on Linux and
Windows, and the visual baselines `docs/06-testing-strategy.md` calls for become
per-host artefacts that nobody can review.

Candidates evaluated against Linux availability, Windows portability, input,
text, dependency weight, maintenance, and CI:

| Candidate | Windows | Text | Weight | CI headless | Owns drawing |
| --- | --- | --- | --- | --- | --- |
| SDL2 | good | needs SDL_ttf | medium | yes (dummy driver) | offers to |
| GLFW + OpenGL | good | none; needs a whole GL text stack | medium | needs GL | yes |
| GTK 3/4 | poor on Windows in practice | excellent | heavy | yes | strongly |
| Qt | good | excellent | very heavy | yes | strongly |
| Xlib + FreeType | n/a (Win32 is the counterpart) | FreeType | very light | yes (Xvfb) | no |

## Decision

**Split the two questions and answer them separately.**

The host abstraction is a *surface and events* contract. `HostWindow` can do
exactly three things: report its size, accept a `Canvas`, and hand back events.
There is no drawing API. `HostBackend` additionally supplies a `TextEngine` that
stops at positioned glyphs and coverage masks — it measures and rasterizes
glyphs, it does not draw strings.

**Rendering lives in shared Swift.** `Rasterizer` composites a `RenderTree` into
a `Canvas` — a 32-bit ARGB framebuffer — using analytic antialiasing for rounded
rectangles and alpha compositing for glyph masks.

**The Linux backend is Xlib plus FreeType plus fontconfig**, behind two thin C
shims. `XPutImage` presents the framebuffer; `XSelectInput` and `XNextEvent`
supply input; FreeType rasterizes glyphs; fontconfig resolves generic families
to files on the host.

**Input is translated once,** from `HostEvent` to Cider's `Touch` abstraction, in
`PointerTranslator`. Nothing above that point has seen a mouse.

## Alternatives Considered

**SDL2.** The obvious choice, and it would have worked. Rejected on dependency
weight relative to what Cider actually needs: with rendering already in shared
code, SDL would be supplying a window, a blit and an event queue — perhaps 400
lines of Xlib — in exchange for a dependency that must be installed on every
developer machine and CI runner. SDL_ttf would still be needed for text, and it
wraps FreeType, which is then a transitive dependency anyway.

**GLFW plus a GL renderer.** Strong windowing portability. Rejected because it
commits Cider to GPU rendering, and GPU text is a large project on its own
(atlas management, subpixel positioning, shader-based coverage). It also makes
headless CI harder — a software GL stack is another dependency with its own
rasterization differences, which is precisely what a visual baseline must not
depend on.

**GTK or Qt.** Both give excellent text and accessibility for free, which is
tempting given `docs/02-product-requirements.md`'s accessibility requirement.
Rejected because both want to own the widget tree, and Cider's entire value is
that it owns its own — Cider would be fighting the framework's layout and event
model forever. GTK on Windows is also a well-known packaging burden, which the
architecture goal specifically warns against.

**A Wayland backend instead of X11.** Wayland is where Linux desktops are going.
Rejected for the first backend because X11 works under XWayland everywhere
Wayland runs, `Xvfb` gives a trivially headless CI path, and the Xlib surface
Cider needs is stable and small. A Wayland backend can be added later as a
sibling implementation without touching anything above `CiderHost` — which is
the whole point of the abstraction.

**Letting the backend rasterize text.** Faster, and a backend could use the
host's native text stack. Rejected: it is the single change that would make
identical applications render differently per host and turn the visual suite
into per-platform baselines.

## Consequences

- The dependency list is three system libraries that every desktop Linux already
  has, and Cider ships no font files (see
  `docs/07-legal-distribution-boundaries.md`).
- CI needs only `Xvfb`. No GPU, no display server package beyond X.
- Rendering is CPU-bound and single-threaded. For a static screen this is
  irrelevant — Cider redraws only on invalidation — but animation will need a
  dirty-rectangle pass or a GPU path, and that is a known future cost.
- Text shaping is one line, left to right, with kerning and no bidirectional
  reordering or complex-script support. Arabic, Devanagari and Thai will render
  incorrectly. Fixing this means HarfBuzz, which is a real dependency decision
  and gets its own ADR when the time comes.
- The Windows backend has a clear, small contract: a window, a blit, an event
  queue, and a `TextEngine`. Roughly `StretchDIBits` and a message pump.
- X11 has no scaling primitive in its core protocol, so the shim letterboxes a
  framebuffer that does not match the window rather than scaling it. A scaled
  presentation would make what a developer sees differ from what a screenshot
  test captures.
