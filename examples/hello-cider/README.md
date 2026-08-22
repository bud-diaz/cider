# hello-cider

The canonical first Cider application, and the vertical slice the runtime is
built to prove: a Swift application, a compatibility API, a normalized UI tree,
a layout pass, a software rasterizer, and a Linux window — with a button that
runs Swift code and visibly changes state.

```
┌───────────────────────────┐
│                           │
│        Cider Demo         │
│                           │
│      [  Press Me  ]       │
│                           │
│         Count: 0          │
│                           │
└───────────────────────────┘
```

Clicking **Press Me** increments the counter.

## Running it

You need a Linux machine with Swift 6.0+, the X11 and FreeType development
packages, and a display. `cider doctor` checks all of that and tells you what to
install if something is missing.

```sh
cd examples/hello-cider
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
| `Sources/HelloCider/HelloCiderApp.swift` | The application. |

## Things to try

Change the button's title, add a second `Text`, or make the button reset the
count instead. Then run `cider run` again — the whole loop stays on Linux.

## Limitations you will hit immediately

This is pre-alpha. The MVP node set is `Text`, `Button` and `VStack`; there is
no scrolling, no text input, no navigation, no images and no networking. See the
root README's roadmap for what is coming and `docs/04-compatibility-specification.md`
for what "supported" will mean when it arrives.
