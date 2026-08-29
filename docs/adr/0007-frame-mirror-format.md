# 0007. Frame mirror format

## Status

Accepted — 2026-08-29.

## Context

The `cider dev` editor shows the running application in a browser, so a
presented frame has to leave the process and be drawn somewhere that is not an
X11 window.

Cider has no image codec, and `tests/visual/PPM.swift` records why: PPM was
chosen for visual baselines because "a header and raw bytes are shorter than the
argument for adding zlib". That reasoning still holds, but PPM itself is no use
here, because no browser can display it.

## Decision

**A 24-byte header followed by straight-alpha RGBA8, and no encoding at all.**

```
"CIDR" | version u32 | pixelWidth u32 | pixelHeight u32 | logicalWidth u32 | logicalHeight u32
```

all little-endian, then `pixelWidth * pixelHeight * 4` bytes.

A browser does not need an encoded image: `putImageData` takes raw bytes. So the
wire format is the same shape as PPM — a tiny header, then pixels — chosen for
the same reason, and the no-codec decision survives intact.

**Both sizes travel**, because the reader needs both and can derive neither.
Pixels size the image; the logical points size the coordinate space inspector
node frames are expressed in, so a reader drawing selection boxes over the frame
needs the ratio.

**Channels are swizzled on the writer's side.** `Canvas` stores `0xAARRGGBB`
words, which on a little-endian host is B, G, R, A in memory. Converting costs
one pass in Swift; leaving it to the reader would cost a per-pixel loop in
JavaScript on every frame.

**Writes are throttled and opt-in.** The runtime writes only when
`inspector.frame-path` is set, which only `cider dev` sets, and at most once
every 200 ms. `phone-standard` is 390×844, so a frame is about 1.3 MB and an
application driving a timer presents at the loop's full 125 Hz; unthrottled, the
mirror would be the most expensive thing in the process.

## Alternatives Considered

**PNG.** Universally displayable, and about a tenth the bytes. Rejected because
it means zlib and a CRC — a new dependency, or a new encoder to maintain — for a
loopback transfer where bandwidth is not scarce. This is the same trade
`tests/visual/PPM.swift` already made.

**PPM.** Already implemented in the test suite. Rejected because browsers cannot
display it, and it drops alpha.

**Replaying `renderCommands` onto a browser canvas.** No new file format, no
throttling, no I/O, and exact node-to-pixel correspondence for selection.
Rejected because the browser would draw text with browser fonts rather than
FreeType, so the canvas would not be what the application looks like — and font
and colour edits are precisely what this editor is for. Selection does not need
it either: node frames from the snapshot already drive that.

**Streaming over the existing HTTP server.** Rejected because that server is a
single-threaded, one-request-per-connection accept loop; a long-lived frame
stream would block every other route.

## Consequences

- A second host backend inherits this for free: the mirror is written from
  `Canvas` in shared code, above the host boundary, so nothing per-platform
  matches it.
- The reader is JavaScript that nothing in this repository can compile, so the
  header layout and channel order are pinned by asserting bytes in
  `FrameMirrorTests` rather than by round-tripping through a decoder.
- A version bump is how the layout changes; a reader that does not recognise the
  version draws nothing rather than guessing.
- `cider run` pays nothing. The cost exists only while `cider dev` is running.
