# image-loading-cider

A narrow reference application for `Image`/`ImageSource`, standalone from
`examples/ui-showcase`'s combined demo. Cider has no image decoder yet — B1's
`ImageSource` is deliberately raw-RGBA8/`.solid(...)` only — so this cycles
through solid-color swatches of different sizes rather than "loading" a file.
That is the honest whole story for `Image` today; see
`docs/known-issues.md`.

```
┌───────────────────────────┐
│      Image Loading         │
│      [ swatch ]            │
│        [ Next ]            │
│    Swatch 1 of 3           │
└───────────────────────────┘
```

## Running it

```sh
cd examples/image-loading-cider
cider doctor
cider run
```

Headless (container/SSH):

```sh
Xvfb :99 -screen 0 1280x1024x24 &
export DISPLAY=:99
cider run
```

## What each file does

| File | Purpose |
| --- | --- |
| `Cider.yaml` | The Cider manifest: identity, device profile, permissions. |
| `Package.swift` | An ordinary SwiftPM executable that links `CiderUI`. |
| `Sources/ImageLoadingCider/ImageLoadingCiderApp.swift` | The application. |

## Conformance coverage

Reuses `UI-IMAGE-001` (`tests/conformance/ConformanceTests.swift`) — this app
proves the primitive in a standalone project, not new behavior.
