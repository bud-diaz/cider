# ui-showcase

Stage 2's reference application: the seven UI primitives it adds --
`Image`, `ScrollView`, `TextField`, `List`, `NavigationView`, `Modal` --
composed into one small app instead of demonstrated in isolation. Each
primitive already has its own conformance test
(`UI-IMAGE-001`/`UI-SCROLL-001`/`UI-TEXTFIELD-001`/`UI-LIST-001`/
`NAV-PUSH-001`/`NAV-POP-001`/`UI-MODAL-001` in
`tests/conformance/ConformanceTests.swift`); this app exists to prove they
hold together, which is what Stage 2's exit criterion actually asks for.

```
┌───────────────────────────┐        ┌───────────────────────────┐
│           Items           │        │          Item 2           │
│  ┌─────────────────────┐  │        │                           │
│  │      Item 0          │ │  tap   │        ┌────────┐         │
│  │      Item 1          │ │  ───►  │        │        │         │
│  │      Item 2          │ │        │        └────────┘         │
│  │         ...           │ │        │      [___________]        │
│  └─────────────────────┘  │        │        [  Back  ]         │
│         [ About ]         │        │                           │
└───────────────────────────┘        └───────────────────────────┘
```

Tapping an item pushes a detail screen (navigation + an image + a bound
text field); **Back** pops it. **About**, reachable from any screen,
presents a dismissable modal over whatever the navigation stack is
currently showing.

## Running it

You need a Linux machine with Swift 6.0+, the X11 and FreeType development
packages, and a display. `cider doctor` checks all of that and tells you what to
install if something is missing.

```sh
cd examples/ui-showcase
cider doctor
cider run
```

With no graphical session — in a container, or over SSH — start a virtual
display first:

```sh
Xvfb :99 -screen 0 1280x1024x24 &
export DISPLAY=:99
cider run
```

## Useful options

```sh
cider run --log-level debug   # trace the runtime's own decisions
cider run --inspect           # print the UI tree on every rebuild
cider run --no-build          # launch what is already built
```

## What each file does

| File | Purpose |
| --- | --- |
| `Cider.yaml` | The Cider manifest: identity, device profile, permissions. |
| `Package.swift` | An ordinary SwiftPM executable that links `CiderUI`. |
| `Sources/UIShowcase/UIShowcaseApp.swift` | The application. |

## Things to try

Scroll the list past the visible rows, type in the detail screen's text
field and navigate back and forward to see it persist (it's one shared
piece of state, not per-item — there is no storage yet, see the root
README's roadmap for Stage 3), or present **About** from a pushed detail
screen instead of the root to see the overlay cover the whole stack, not
just one screen.

## Limitations you will hit immediately

This is pre-alpha. `List` has no virtualization, a modal presentation is
always full-screen (no partial-height sheet), and the text field has no
composed/IME input on the real X11 backend yet — see `HANDOFF.md` at the
repository root for the exact state of each primitive. There is still no
networking or persistent storage; see the root README's roadmap for what
Stage 3 adds.
