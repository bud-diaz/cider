# 0008. Source write-back: what the rewriter may do

## Status

Accepted — 2026-08-29.

## Context

The `cider dev` editor changes a property by rewriting the developer's Swift.
`cider dev` then rebuilds and runs whatever landed on disk, so a wrong edit is
not an inconvenience — it compiles and executes.

There is no runtime override channel by design: the source stays the one source
of truth, and the existing file watcher closes the loop. That decision makes the
rewriter the only thing standing between a click and a modified file.

## Decision

**The rewriter does exactly two things.** It replaces a span it has *proved* is
a single literal, or it appends a fully-formed modifier at a chain end it has
*proved* is well-formed. It never deletes, never reflows, never reorders, and
never touches a span containing a comment. Anything it cannot prove, it declines.

**A token scanner, not a parser, and no swift-syntax dependency.** The editor
never needs to understand a program — it needs to find one expression and splice.
What lets a scanner stand in for a parser is that the walk never guesses: a `{`
is consumed as a trailing closure only after a call in a known whitelist, and
anything else ends the chain rather than being interpreted.

**Edits are addressed by source position, never by `NodeID`.** A structural path
can be re-keyed by a state change between the snapshot and the click; a file
position cannot. No node id crosses the wire.

**The recorded origin is an anchor, not a locator.** `#column` for a chained call
resolves to the start of the whole expression, so the editor finds the chain head
at the anchor and walks the chain by selector name — taking the *last* matching
segment, because copy-and-overwrite means that is the one whose value the node
carries.

**One selector per editable property, and no overloads.** The locator finds a
modifier by name with no type information, so two `padding` overloads would make
"which argument list is this" unanswerable. This constrains the compatibility API
and is the reason ADR 0006's parameter additions are shaped the way they are.

**Three staleness guards.** The anchor must still name the expected view
(`CID0635`); the value must still be what the panel displayed, compared
numerically for doubles (`CID0634`); and a second edit is held until the
application has relaunched (`CID0642`), so no edit is ever aimed at line numbers
a previous one moved.

**A colour is written as `Color(hex:)` and gets its own proof.** A colour is
never a bare token, and it is the property an editor is most often asked to
change; a `Color(hex:)` call whose arguments are themselves literals is as safe
to replace as a literal. A named colour is refused.

**Refusals are diagnostics, not statuses.** `CID0630`–`CID0643`, each with a
reason and a remedy, reaching the browser as the four parts of a `Diagnostic`.

**The console decodes the snapshot it serves.** `CiderProject` depends on
`CiderInspector` so the schema is compile-checked at both ends rather than
duck-typed through JavaScript. This does not breach "the CLI links neither the
runtime nor a backend": `CiderInspector` depends only on `CiderCore` and
`CiderUITree`. New snapshot fields are added as optionals, so a console and a
runtime one version apart degrade rather than fail.

## Alternatives Considered

**swift-syntax.** Correct by construction, and it would give real source ranges.
Rejected on three counts: it is a new dependency with a significant build cost;
it still cannot map a *runtime* node back to a source range without the origin
table this design needs anyway; and the rewriting the editor does is a splice,
not a transformation, so a full syntax tree buys precision the splice does not
use.

**Regenerating the view body from the UI tree.** Would make structural edits
possible. Rejected because it rewrites code the developer did not ask to be
touched — comments, formatting, intermediate values — and Cider's tree is lossy
with respect to the source that produced it.

**Rewriting whatever is at the recorded position.** Simplest, and wrong: the one
thing that must never happen is a splice at an offset the editor has not
verified.

**Refusing colours.** Would have been consistent with "literals only". Rejected
because it makes the most-wanted edit permanently impossible, and a
`Color(hex:)` call built from literals is provably as inert as a literal.

**Structural editing — add, delete, reorder.** Rejected for v1. `NodeID` is a
structural path, so inserting a sibling re-keys every following node and its
descendants; selection and any in-flight edit would silently re-target.
Structural editing needs developer-supplied keys first, exactly as ADR 0003
predicted under "Identity from an explicit developer-supplied key".

## Consequences

- Many real edits are refused: an expression, a named constant, an interpolated
  string, a multi-line argument list, a file the watcher does not watch. This is
  the intended trade — a refused edit costs one manual change, and a wrong one
  costs a file.
- One source site can be several nodes (a view built in a loop). The edit
  succeeds and changes all of them, because that is what the developer wrote.
- The editable set is a table, not a rule. A new editable property means an
  entry, and a new view kind means the property is not editable until someone
  adds one.
- Every applied edit is recorded in the event stream with what it replaced, so
  an unwanted one is recoverable without relying on memory. There is no undo.
- Tests assert whole files, not changed lines, and every refusal asserts the file
  came back byte-identical. A rewriter that quietly reflowed the rest of a file
  would pass a test that only looked at one line.
