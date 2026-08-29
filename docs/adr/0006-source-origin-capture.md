# 0006. Source origin capture

## Status

Accepted — 2026-08-29.

## Context

The `cider dev` editor changes a view's property by rewriting the Swift that
produced it. That needs a link from a node in a running process back to the call
in a file that built it — and nothing in Cider had one. The UI tree is
deliberately pure data with structural-path identity (ADR 0003); a `NodeID` says
where a node sits in a tree, not where a developer wrote it.

There is a second, sharper question underneath. For an edit to know whether it
should *rewrite an argument* or *insert a modifier*, it has to distinguish "the
developer wrote this value" from "this value came from `Theme` or from a
defaulted parameter". After a call returns, a defaulted argument is
indistinguishable from a passed one.

## Decision

**Origins are captured through defaulted location parameters.**

```swift
public init(_ content: String, file: String = #filePath, line: Int = #line, column: Int = #column)
```

Default arguments are evaluated at the *caller*, which is the only place that
knows where a view was written. No call site mentions them.

**They go last in every signature.** Swift's forward-scan trailing-closure
matching binds `VStack { }` to `content` and `Button("x") { }` to `action`
regardless, because the location parameters are not function-typed.

**`#filePath`, not `#fileID`.** `#fileID` is `Module/File.swift`, so two files
with the same name in different directories are indistinguishable, and there is
no index to resolve one back to a path.

**Origins travel beside the tree, never inside `UINode`.**
`ApplicationScene.origins: [NodeID: NodeOrigins]`, alongside the `actions` and
`textInputHandlers` side tables ADR 0003 established for the same reason.

**`NodeOrigins` records the view type's name** as well as the position, because
the node kind does not always name the view: a `List` lowers to a
`ScrollViewNode`.

**A property is recorded only when it was written.** Where an initializer
argument has a default, the parameter becomes `Optional` and defaults to `nil`
— `VStack(spacing:alignment:)`, `List(spacing:)` — so the initializer can tell
whether the caller passed one. Behaviour when omitted is unchanged.

**Synthetic wrapper nodes record nothing.** `ScrollView`'s `/wrap`, `List`'s
`/rows`, `NavigationView`'s `/screen`, `Modal`'s two slots and the root stack
`Lowering.scene` builds for a multi-node body have no call site.

## Alternatives Considered

**Origins inside `UINode`.** Shorter — no side table, no second lookup. Rejected
because it costs exactly what ADR 0003 bought: `UINode` is `Equatable` and
`Sendable`, the whole conformance and visual suite compares node values, and a
file path is neither stable across machines nor meaningful to compare.

**A macro.** Precise, and it could record a full source range rather than a
point. Rejected because it means a swift-syntax dependency — an ADR-level
decision on its own, with a large build-time cost — for a developer-tool feature.

**A build-time source index.** Would give ranges without touching any signature.
Rejected because building one needs a real parser, and it would go stale between
a build and an edit in exactly the situation the editor exists for.

**Attributing a parent's origin to its synthetic wrappers.** Would make
`List.spacing` editable through the `/rows` node it actually lives on. Rejected
because it aims an edit at an expression that does not contain the value; the
list's own origin covers the same case honestly.

## Consequences

- Every public view initializer and modifier gains three defaulted parameters.
  This is a public API shape change, and it is why one modifier per property
  with no overloads is now a rule (ADR 0008 depends on it).
- `#filePath` embeds absolute build-machine paths in the binary. Debug builds
  already carry them in debug info, but a release build of an application using
  `CiderUI` now carries developer paths in its string table too. Recorded in
  `docs/known-issues.md`.
- What the compiler reports for a *chained* call could not be verified without a
  toolchain, so nothing depends on it: `EDIT-ORIGIN-002` proves only that two
  views on one line get distinct columns, which is what the editor needs.
- Origins are empty for any scene built by something that does not record them,
  so the runtime and the tests work unchanged with the table absent.
