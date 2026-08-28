# Performance Baseline

Stage 5 requires a performance baseline before Cider is presented as a public alpha. This file defines the baseline shape and the repeatable commands; measured release numbers still need to be recorded on the supported CI/host matrix.

## Baseline scope

Measure at least:

1. Root debug and release build time.
2. Root unit/conformance/integration/visual test time.
3. Example-app build time for every `examples/*` package.
4. `cider run --no-build --inspect` startup-to-first-inspector-snapshot for reference apps.
5. Basic render/update latency for the Stage 2 UI primitives under the testing backend.
6. Xvfb smoke time for `scripts/validate-stages3-4.sh`.

## Current commands

```sh
/usr/bin/time -p swift build
/usr/bin/time -p swift test
/usr/bin/time -p swift build --configuration release
/usr/bin/time -p swift test --configuration release

for example in examples/*/; do
  (cd "$example" && /usr/bin/time -p swift build)
done

/usr/bin/time -p scripts/validate-stages3-4.sh
```

In environments without a host Swift toolchain, use the same Swift 6.0 Noble Docker path as CI and mount the checkout at `/home/bud/cider` so example path dependencies keep the expected package identity.

## Measured results (v0.1.0-alpha.0)

Measured 2026-08-28 in the `swift:6.0-noble` container (Swift 6.0.3, x86_64-unknown-linux-gnu, 4 vCPU / 30GiB host), the same environment CI's `ubuntu-24.04` matrix leg uses. **Scoped to `noble` only** — CI's second leg, `swift:6.0-jammy` (Ubuntu 22.04), is verified to build and pass the same 223 tests (see `HANDOFF.md`) but was not separately re-profiled for this baseline; treat `jammy` timing as broadly equivalent, not independently measured.

1. **Root build time** — debug: 9.0s wall (`swift build`, from clean incremental state); release: 20.6s wall (`swift build --configuration release`).
2. **Root test time** — debug: 14.0s wall for `swift test`, of which the suite itself reports 223 tests in 2.1s; the remainder is build-for-testing overhead. Release: 29.7s wall (`swift test --configuration release`), suite itself 2.5s.
3. **Example-app build time** — all 10 `examples/*` packages, each an incremental `swift build` against an already-built root: 2.6-2.7s wall per app (dominated by re-resolving/re-linking the path dependency on the root package, not app-specific code).
4. **`cider run --no-build --inspect` startup-to-first-inspector-snapshot** — `examples/hello-cider`, measured wall-clock from process spawn to the `application started` log line appearing (polled at 50ms resolution): ~2.2s in this containerized X11 environment (process exec, dynamic linking, X11 connection handshake, first layout/render). This is a coarse proxy, not an instrumented in-process timer — Cider has no internal startup-latency instrumentation yet.
5. **Render/update latency for Stage 2 primitives (testing backend)** — from the conformance suite's own per-test XCTest timings (includes XCTest/assertion overhead, not isolated render time): simple node tests (`UI-TEXT-001`, `UI-BUTTON-001`) complete in 1-3ms; a full pixel-level PPM comparison (`STATE-UPDATE-001`'s `testSTATE_UPDATE_001_pixelsChange`) takes ~129ms; a tap-and-redraw round trip (`testSTATE_UPDATE_001_tappingIncrementsAndRedraws`) takes ~12ms.
6. **Xvfb smoke time for `scripts/validate-stages3-4.sh`** — 63.3s wall, dominated by the script's fixed `sleep`s around real X11 window interaction (Notes save/load, REST-client GET, Stage 4 CLI flow), not raw compute.

Re-measure when the supported CI/host matrix changes (a new Swift version, a new Ubuntu LTS actually profiled, or new hardware).

## Alpha status

Public alpha numbers for `v0.1.0-alpha.0` are recorded above on the `noble` leg of the supported matrix. `jammy` is assumed comparable pending its own measurement pass.
