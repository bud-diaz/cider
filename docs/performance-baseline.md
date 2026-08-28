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

## Alpha status

No public alpha numbers are published yet. This is intentional: the baseline document is now present and testable via `cider alpha-readiness`, but Stage 5 should not be marked complete until the numbers are recorded for the claimed Ubuntu support matrix.
