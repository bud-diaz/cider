# modal-presentation-cider

A narrow reference application for `Modal` alone, standalone from
`examples/ui-showcase` (which wraps a `NavigationView` inside a `Modal`).
There's no navigation stack here — just the top-level base/presented pair.

```
┌───────────────────────────┐
│       Base Screen           │
│        [ Show ]             │
└───────────────────────────┘
```

Tapping **Show** dims the base and presents a sheet; **Close** dismisses it.

## Running it

```sh
cd examples/modal-presentation-cider
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
| `Sources/ModalPresentationCider/ModalPresentationCiderApp.swift` | The application. |

## Conformance coverage

Reuses `UI-MODAL-001` (`tests/conformance/ConformanceTests.swift`) — this app
proves the primitive in a standalone project, not new behavior.
