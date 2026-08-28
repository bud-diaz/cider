# Contributing to Cider

> Cider is licensed under [Apache-2.0](LICENSE) (see [`NOTICE`](NOTICE) for
> third-party attribution). Cider is still pre-alpha, and this document
> describes the standards that apply to any contribution now.
>
> By submitting a Contribution, you agree it is licensed under Apache-2.0,
> consistent with the License's own Section 5 ("Submission of
> Contributions") — there is no separate CLA or DCO sign-off required at
> this stage.

## Before you write code

Read [`docs/`](docs/README.md). The seven documents there are the source of
truth, and an implementation that contradicts them needs either a strong
technical reason or a change to the document — never a silent divergence.

If you are about to make a decision that is hard to reverse, write an
[ADR](docs/adr/README.md) first. "Hard to reverse" means: a new dependency, a
language boundary, a public API shape, a file format, or anything that a second
platform backend would have to match.

## Hard boundaries

These are not style preferences. A change that crosses one of them cannot be
merged, whatever else it does.

Do not add to this repository:

- iOS firmware, or anything derived from it;
- Apple simulator runtime files;
- copied UIKit, SwiftUI or Foundation implementation code or headers;
- Apple SDK files, certificates, fonts, icons or device artwork;
- anything whose purpose is to bypass code signing, DRM, activation or device
  locks;
- code of unclear provenance.

Compatibility work must be based on public documentation, observable behaviour of
programs you own, published standards, or permissively licensed code with
compatible terms. For anything sensitive, include a short provenance note in the
pull request: what public behaviour you were implementing, and what you worked
from.

Full policy: [`docs/07-legal-distribution-boundaries.md`](docs/07-legal-distribution-boundaries.md).

## Architecture rules

The target graph in `Package.swift` enforces the dependency direction. A change
that needs it relaxed is a design discussion, not a build fix.

- **Nothing above `CiderHost` may know which platform it is on.** Exactly one
  module — `CiderHostBootstrap` — names a concrete backend. If you find yourself
  adding `#if os(Linux)` anywhere else, the abstraction has sprung a leak and
  that is the bug.
- **Backends do not draw.** A backend supplies a window, a surface, an event
  queue, and glyph coverage masks. Compositing happens in shared code, because
  the moment a backend owns it, the same application renders differently per host
  and visual baselines stop being reviewable.
- **The CLI links neither the runtime nor a backend.** `cider doctor` has to run
  on a machine where the thing it is diagnosing is missing.
- **The UI tree stays pure data.** No closures in nodes; actions travel beside
  the tree keyed by node identity.

## Code standards

Write code that reads like the code around it.

- **Small modules, explicit interfaces.** If a type needs a paragraph to explain
  why it exists, that paragraph goes above it.
- **Comments explain why, not what.** `// increment the counter` above `count +=
  1` is noise. `// A radius larger than half the shorter side would invert the
  corner arc.` is the comment worth having. Where a decision has a non-obvious
  alternative, say which alternative you rejected.
- **Diagnostics, not strings.** Anything a developer sees when something goes
  wrong is a `Diagnostic` with a code, a summary, a reason and a remedy.
  "Runtime initialization failed: code 127" is the failure mode to avoid.
- **Errors get stable codes.** `CID0501` is searchable; a rephrased sentence is
  not. Do not reuse a retired code.
- **Public API is documented.** Every public type and method carries a doc
  comment saying what it does and, where it matters, what it deliberately does
  not.

C shims:

- flat C surface, no policy;
- compile clean under `-Wall -Wextra`;
- never return a bare error code where a message would help;
- own their allocations, so callers never free anything.

## Tests

`docs/06-testing-strategy.md` puts it plainly: the test suite *is* the
compatibility contract. A feature is not supported because a demo worked once.

| Suite | What belongs there |
| --- | --- |
| `tests/unit/` | Pure logic: layout maths, parsing, geometry, formats. |
| `tests/conformance/` | Application-visible behaviour, driven through a real runtime. |
| `tests/integration/` | Whole flows across several components, against real on-disk projects. |
| `tests/visual/` | Rendered output against committed baselines. |

Rules:

- **Every application-visible behaviour gets a conformance ID** —
  `UI-BUTTON-002`, `NET-HTTP-001`. Once an ID is published it is never renamed:
  a renamed test is an unverifiable claim.
- **Tests must not depend on the machine.** Use `DeterministicTextEngine`, not
  the host's fonts. Use `TestingHostBackend`, not a display.
- **Assert on numbers, not screenshots, wherever a number will do.** Visual
  baselines are for the renderer itself.
- **Re-record baselines deliberately.** `CIDER_UPDATE_BASELINES=1 swift test
  --filter CiderVisualTests` fails on purpose. Look at the image before you
  commit it — a baseline updated without looking is a test switched off.

Run everything before opening a pull request:

```sh
swift build
swift test
```

## Pull requests

- One concern per pull request.
- Say what you changed and why. Link the ADR if there is one.
- Update `CHANGELOG.md` under `[Unreleased]`.
- Update the "Current limitations" list in `README.md` if you removed one — an
  out-of-date limitations list is worse than none, because it overclaims.
- New dependency? It needs an ADR and an entry recording package, version,
  license, purpose, source and redistribution obligations.

## Marketing language

`docs/07-legal-distribution-boundaries.md` section 10 applies to code comments,
commit messages and documentation alike. Do not write "iOS emulator", "runs
iPhone apps", "Xcode replacement" or a compatibility percentage. Describe the
tested subset precisely, or say nothing.

Device profiles use generic names. `phone-standard`, never a product name.
