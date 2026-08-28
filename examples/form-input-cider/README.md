# form-input-cider

A narrow reference application for a bound, editable `TextField` and a
submit round-trip — no persistence involved (contrast with
`examples/notes-cider`, which pairs `TextField` with `CiderStorage`/
`CiderPreferences`).

```
┌───────────────────────────┐
│        Form Input          │
│  [ draft text field   ]    │
│      [   Submit   ]        │
│    Submitted: ...          │
└───────────────────────────┘
```

Type in the field, tap **Submit**, and the submitted line updates.

## Running it

```sh
cd examples/form-input-cider
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
| `Sources/FormInputCider/FormInputCiderApp.swift` | The application. |

## Conformance coverage

Reuses `UI-TEXTFIELD-001` (`tests/conformance/ConformanceTests.swift`) — this
app proves the binding in a standalone project, not new behavior.
