# 0003. Normalized UI tree model

## Status

Accepted — 2026-08-22.

## Context

`docs/03-technical-architecture.md` section D asks for an internal tree
independent of both the application API and the host renderer, to create "a
testable seam between API compatibility and graphics."

The question is what that tree contains, and specifically what happens to
callbacks. A button has an action. If the action lives in the node, the tree
holds closures — and a tree with closures in it cannot be compared, cannot be
printed, cannot be `Sendable`, and cannot be checked for equality in a test.

There is also the question of identity. When state changes, Cider rebuilds the
whole tree. Something has to say that the button in the new tree is the same
button the user is currently holding down, or a press would be lost on every
state change that happens under the finger.

## Decision

**Three node kinds for the first milestone**: `TextNode`, `ButtonNode`,
`VStackNode`, wrapped in an `indirect enum UINode`.

**The tree is pure data.** `UINode` is `Equatable` and `Sendable`. A button does
not carry its action; it carries its identity. Actions travel beside the tree in
an `ApplicationScene`:

```swift
struct ApplicationScene {
    var root: UINode
    var actions: [NodeID: ActionHandler]
}
```

**Identity is the structural path from the root**: `root/0/1`. The same view
structure always lowers to the same identities.

**Layout is two passes, no constraints**: `measure` bottom-up, `place`
top-down. `LayoutBox` carries absolute frames.

**A render tree flattens the placed tree** into an ordered list of drawing
commands plus a list of hit regions. Painter's order is explicit; hit testing is
a reverse scan over a list.

**The pipeline runs in five stages:**

```
Swift view values  →  UINode tree  →  LayoutBox  →  RenderTree  →  Canvas
    (CiderUI)        (lowering)      (layout)      (flatten)     (rasterize)
```

## Alternatives Considered

**Closures in nodes.** Shorter — no side table, no identity scheme needed for
dispatch. Rejected because it costs `Equatable`, `Sendable`, printability and
comparability, all of which the conformance and visual suites depend on. The
side table costs one dictionary lookup per tap.

**Rendering straight from view values, with no intermediate tree.** Fastest to
build and the shortest path to a first screenshot. Rejected because it is exactly
the seam `docs/03-technical-architecture.md` asks for: without it, every
renderer test needs the application API, and every API change is a renderer
change.

**A retained, mutable node tree with diffing.** What a mature framework does, and
where Cider will end up. Rejected for now because a diffing algorithm designed
against three node kinds would be designed against guesses. Full rebuild is
wasteful and completely adequate at this size, and the structural-path identity
scheme is the piece diffing will need when it arrives.

**Identity from an explicit developer-supplied key.** More robust under
reordering — a structural path changes when a sibling is inserted above.
Rejected as premature: with no list or `ForEach` in the MVP node set there is
nothing to reorder, and requiring keys before they matter is a step a developer
can only get wrong. This will need revisiting when lists arrive.

**A flat display list with no tree at all.** Rejected because nesting is what
`VStack` means, and flattening at lowering time would lose the structure the
layout engine needs.

## Consequences

- The tree can be compared in a test, printed by the inspector, and eventually
  serialized for a remote inspector, without any of those features being
  designed for now.
- Every state change rebuilds and re-lays out the entire tree. Fine for a screen;
  a real cost for a long list, and the reason diffing is on the roadmap.
- Structural identity is stable across rebuilds of the same structure, but *not*
  across a structural change. Inserting a view above a pressed button re-keys it
  and drops the press. The runtime handles the related case — a pressed node that
  vanishes in a rebuild is un-pressed rather than left dangling.
- Adding a node kind means touching `UINode`, `LayoutEngine.measure`,
  `LayoutEngine.place`, `RenderTreeBuilder` and `Inspector`. That is five places,
  deliberately: each is a decision the new node has to make explicitly.
- Hit regions are published only by interactive nodes, so text and stacks are
  transparent to input without any explicit "hit testing disabled" flag.
