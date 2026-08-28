# nav-list-cider

A narrow reference application for `NavigationView` over a `List`, standalone
from `examples/ui-showcase` (which combines navigation, list, form, image and
modal into a single showcase app).

```
┌───────────────────────────┐
│          Rooms             │
│  [ Room 0 ]                │
│  [ Room 1 ]                │
│  ...                       │
└───────────────────────────┘
```

Tapping a row pushes a detail screen; **Back** pops it.

## Running it

```sh
cd examples/nav-list-cider
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
| `Sources/NavListCider/NavListCiderApp.swift` | The application. |

## Conformance coverage

Reuses `UI-LIST-001`, `NAV-PUSH-001` and `NAV-POP-001`
(`tests/conformance/ConformanceTests.swift`) — this app proves the primitives
compose in a standalone project, not new behavior.
