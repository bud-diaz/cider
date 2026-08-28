# timer-clipboard-cider

A narrow reference application for `CiderTimer` — the one Stage 3 service
with conformance coverage (`TIMER-001`) but no reference-app coverage until
this app. Paired with a minimal `CiderClipboard` touch (already exercised by
`examples/notes-cider` and `examples/rest-client-cider`).

```
┌───────────────────────────┐
│     Timer + Clipboard       │
│    [ Start Timer ]          │
│    [ Copy Status ]          │
│    [   Paste    ]           │
│         Idle                │
└───────────────────────────┘
```

**Start Timer** sets the status, then flips it after half a second via
`CiderTimer.after`. **Copy Status**/**Paste** round-trip the status through
`CiderClipboard`.

## A known caveat

`CiderTimer.after`'s callback runs on a background dispatch queue, not the
runtime's pump loop — mutating `@CiderState` from it, as this app does, is
not synchronized with rendering. That is Cider's actual behavior today; see
`docs/known-issues.md`.

## Running it

```sh
cd examples/timer-clipboard-cider
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
| `Sources/TimerClipboardCider/TimerClipboardCiderApp.swift` | The application. |

## Conformance coverage

Reuses `TIMER-001` and `CLIPBOARD-001`
(`tests/conformance/Stage3ServiceTests.swift`) — this app proves the
services in a standalone project, not new behavior.
