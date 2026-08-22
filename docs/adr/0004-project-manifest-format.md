# 0004. Project manifest format

## Status

Accepted — 2026-08-22. Manifest schema version 1.

## Context

`docs/03-technical-architecture.md` section 5 requires a Cider-owned manifest so
a project's runtime metadata does not depend on a proprietary project format,
and `docs/07-legal-distribution-boundaries.md` section 2 forbids depending on
one. The illustrative shape in the architecture document is YAML.

Two questions follow. Does Cider take a YAML dependency? And does the runtime
read the manifest, or does the toolchain?

The second matters more than it looks. If the runtime parses YAML, then every
application binary links a YAML parser, manifest validation errors surface at
launch instead of at build time, and the file-and-line diagnostics
`docs/02-product-requirements.md` FR-007 asks for have to be reproduced in two
places.

## Decision

**A YAML-shaped file called `Cider.yaml`, parsed by a deliberately small
project-owned parser.** Supported: nested mappings, two-space indentation,
scalars, single and double quotes, `#` comments. Not supported: sequences,
anchors, aliases, tags, flow collections, multi-document files, multi-line
scalars. Anything unsupported is **rejected with a line number**, never guessed
at.

**Unknown keys are errors, not warnings.** A setting that is silently ignored is
one a developer believes is in effect.

**Every problem is reported at once.** Parsing collects diagnostics into a
`DiagnosticBundle` rather than throwing on the first one.

**Validation is aggressive.** Application identifiers must be reverse-DNS, entry
names must be valid Swift type names, compatibility versions must be
`MAJOR.MINOR`, permissions must be literally `true` or `false` — `yes` is an
error.

**Absent permissions are denied.** A capability the developer did not ask for is
not one Cider grants.

**The toolchain reads the manifest; the runtime never does.** `cider run`
validates `Cider.yaml`, resolves the device profile and command-line overrides,
and writes a versioned **launch descriptor** — a flat `key = value` text file —
that the runtime reads. The descriptor carries `descriptor-version` and a
runtime refuses one it does not understand rather than guessing.

The manifest itself carries an optional `manifestVersion`.

## Alternatives Considered

**A real YAML library (Yams or libyaml).** Correct YAML, no parser to maintain.
Rejected on surface area rather than size: adopting YAML means adopting all of
it, and the moment a developer writes an anchor or relies on YAML 1.1's `yes`
being boolean, that behaviour is part of Cider's compatibility contract forever.
The failure mode is not a crash, it is a manifest that means something subtly
different from what it looks like. The subset parser is roughly 200 lines and
rejects everything it does not implement.

**TOML or JSON.** Both have unambiguous grammars and good libraries. JSON
rejected because it has no comments, and a manifest a developer cannot annotate
is a manifest they will annotate in a README instead. TOML rejected only because
the architecture document already illustrates YAML and the shape is familiar to
the audience; it would have been a defensible choice.

**A Swift file, like `Package.swift`.** No parser at all, full type checking, and
the audience already knows the pattern. Rejected because it means the manifest
cannot be read without running a compiler — `cider doctor` and `cider run` on a
machine with a broken toolchain could not read it, and neither could an editor
plugin or a CI job that only wants the app id.

**Letting the runtime parse the manifest directly, with no descriptor.** One
format instead of two. Rejected because it links a parser into every application
binary, moves validation errors from build time to launch time, and offers
nowhere to put resolved command-line overrides. The descriptor also makes the
CLI-to-runtime contract explicit and versioned, so the two can be upgraded
independently.

**Accepting unknown keys with a warning.** Friendlier to forward compatibility.
Rejected because warnings scroll past, and the specific failure — a developer
writes `localstorage` instead of `localStorage` and the permission is silently
denied — is invisible until something else breaks.

## Consequences

- The manifest is readable without a Swift toolchain, by Cider or by anything
  else.
- A developer who knows YAML will occasionally hit a rejection for something YAML
  allows. The diagnostic says which line and what is supported, and the parser's
  refusals are covered by tests.
- Two formats exist and both are versioned. `manifestVersion` and
  `descriptor-version` move independently, which is the point.
- Adding a manifest field means touching the parser's key sets, `Manifest`, the
  descriptor, and `LaunchDescriptor.decode`. The compiler catches three of the
  four.
- Because the descriptor is a file, `cider run --log-level debug` leaves
  `.cider/launch.descriptor` behind, which is readable in a bug report.
- An application launched directly, without the CLI, gets documented defaults
  rather than failing — so a debugger session is not a different code path from
  the supported one.
