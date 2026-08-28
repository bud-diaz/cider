# lifecycle-cider

A narrow reference application for the app-level lifecycle hooks,
`CiderApp.didEnterBackground()`/`didEnterForeground()`, added alongside this
app. `ApplicationRuntime.enterBackground()`/`enterForeground()` (Stage 3)
already simulate the transition and are covered by `LIFE-BG-001`, but
nothing previously called into application code when they fired — that's
what this app and `LIFE-BG-002` prove.

```
┌───────────────────────────┐
│        Lifecycle             │
│        Launched              │
└───────────────────────────┘
```

## A known caveat

**Nothing in `cider run` itself drives a background/foreground transition
yet.** There is no real OS app-switcher signal on Linux, and no CLI/dev-console
control to simulate one interactively — only test and harness code
(`ApplicationRuntime.enterBackground()`/`enterForeground()`, exercised by
`LIFE-BG-001`/`LIFE-BG-002`) can trigger it today. Running this app normally,
the log will only ever show "Launched." See `docs/known-issues.md`
(`CIDER-KI-0009`).

## Running it

```sh
cd examples/lifecycle-cider
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
| `Sources/LifecycleCider/LifecycleCiderApp.swift` | The application. |

## Conformance coverage

Reuses `LIFE-BG-001` and the new `LIFE-BG-002`
(`tests/conformance/Stage3ServiceTests.swift`).
