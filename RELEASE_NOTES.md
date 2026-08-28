# Cider v0.1.0-alpha.0

Tag: `v0.1.0-alpha.0`. Compatibility contract: `0.1`
(`docs/alpha-compatibility-contract.md`). This is the first tagged alpha
milestone — a build-from-source developer preview, not a public,
package-distributed release.

## What this tag covers

- Compatibility contract `0.1`: the conformance IDs and
  `compatibility-registry.md` entries that exist at this tag are stable for
  the `0.1` line, per `docs/alpha-compatibility-contract.md`'s stability
  rule (no silent renames, no silent removals, downgrades documented).
- CLI/alpha version string: `0.1.0-alpha.0`
  (`compiler-support/Sources/CiderProject/AlphaReadiness.swift`).

## Stage 5 gate status at this tag

Run `cider alpha-readiness` for the live, authoritative report. At this tag:

| Requirement | Status | Note |
| --- | --- | --- |
| installation packaging | **partial (accepted alpha caveat)** | Source build only — no signed archives or package-manager distribution. This will not flip to done by itself; see "Accepted caveats" below. |
| versioned compatibility contract | done | Tagged here. |
| security reporting | done | GitHub private vulnerability reporting is enabled on the repo and documented in `SECURITY.md`. |
| contribution policy | done | Licensed under Apache-2.0 (`LICENSE`); `CONTRIBUTING.md` is open. |
| known-issues database | done | `docs/known-issues.md` records 10 alpha caveats. |
| performance baseline | done | Measured numbers recorded in `docs/performance-baseline.md`. |
| at least 10 reference applications | done | 10 apps under `examples/`. |
| CI on supported Ubuntu versions | done | CI now matrices `ubuntu-24.04` (noble) and `ubuntu-22.04` (jammy). |

## Accepted caveats

Per `docs/stage5-alpha-readiness.md`'s completion rule, a Stage 5 gate may be
closed either by completing it or by explicitly accepting it as a documented
alpha caveat here:

- **Installation packaging** is accepted as open for this tag. Signed binary
  archives and package-manager distribution need real release infrastructure
  (signing keys, a package repository) this project does not have yet.
  Build from source per `docs/install.md` (`CIDER-KI-0007`).
- **`examples/lifecycle-cider` has no interactive trigger.** The new
  `CiderApp.didEnterBackground()`/`didEnterForeground()` hooks are real and
  conformance-tested (`LIFE-BG-002`), but nothing in `cider run` itself
  drives a background/foreground transition yet (`CIDER-KI-0009`).
- **`jammy` (Ubuntu 22.04) performance is not separately measured.** The
  recorded baseline numbers are from `noble` only; `jammy` is verified to
  build and pass the same tests but assumed, not profiled, to perform
  comparably (see `docs/performance-baseline.md`).
- **`CiderTimer` callbacks run off the render thread**, discovered while
  building `examples/timer-clipboard-cider` — the first reference-app use of
  the service (`CIDER-KI-0010`).

See `docs/known-issues.md` for the full, itemized list.

## Getting it

There is no packaged binary. Build from source:

```sh
git clone https://github.com/bud-diaz/cider.git
cd cider
swift build
```

See `docs/install.md` for prerequisites and `README.md` for the full
current-limitations list.
