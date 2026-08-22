# Windows backend

Not yet written. Stage 6 of
[`docs/05-implementation-roadmap.md`](../../docs/05-implementation-roadmap.md).

This directory is here because the architecture treats Linux as the *first*
backend rather than the architecture itself. Everything above
[`host/Sources/CiderHost`](../Sources/CiderHost) is written against protocols,
and exactly one module — `CiderHostBootstrap` — is allowed to name a concrete
backend.

## What a Windows backend has to supply

The same contract the Linux backend implements, and nothing more:

| Protocol | Responsibility | Likely Win32 counterpart |
| --- | --- | --- |
| `HostBackend` | Open windows, create a text engine | — |
| `HostWindow` | Report size, accept a `Canvas`, drain events, close | `CreateWindowEx`, `StretchDIBits`, `PeekMessage` |
| `TextEngine` | Metrics, shaping to positioned glyphs, glyph coverage masks | DirectWrite, or FreeType again |

`Canvas` is a 32-bit ARGB framebuffer in `0xAARRGGBB` word order, which on
little-endian is byte-order B, G, R, A — the layout a top-down `BITMAPINFO`
expects, so no conversion pass is needed.

## What it must not do

**A backend does not draw.** No `drawText`, no `fillRect`. Cider rasterizes in
shared code so that the same application produces the same pixels on every host,
which is what makes the visual baselines in
[`docs/06-testing-strategy.md`](../../docs/06-testing-strategy.md) reviewable
rather than per-platform.

**A backend does not interpret input.** It reports pointer events; the runtime
turns them into touches.

See [ADR 0002](../../docs/adr/0002-linux-windowing-backend.md) for why the
contract is drawn where it is, and
[`host/linux/`](../linux) for the reference implementation — roughly 400 lines of
C plus 300 of Swift.

## Before starting

`docs/05-implementation-roadmap.md` puts Windows after Stage 5 for a reason: the
host contract should be stable first. Porting against a contract that is still
moving means porting twice.
