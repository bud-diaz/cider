# Cider Alpha Compatibility Contract

Cider's first alpha-track compatibility contract is `0.1`.

The contract is deliberately narrow. A behavior is considered part of the alpha contract only when it is covered by at least one of these sources:

1. a published conformance ID in `HANDOFF.md` / `tests/conformance/`;
2. an entry in `docs/compatibility-registry.md` generated from `CompatibilityRegistry`;
3. a documented CLI behavior covered by unit/integration tests;
4. a visual baseline in `tests/visual/Baselines/` for renderer output.

Everything else is experimental, even when a demo happens to work.

## CLI/runtime version

The current alpha-track CLI version is `0.1.0-alpha.0`.

## Compatibility levels

| Level | Meaning |
| --- | --- |
| A | Compatible within the explicitly tested Cider subset. |
| B | Supported with documented differences from Apple platform APIs or common expectations. |
| C | Development stub; useful for local app work but not a faithful implementation. |
| D | Recognized unsupported surface; scanner/docs can point at it, but Cider does not implement it. |

## Stability rule

For the `0.1` alpha line:

- conformance IDs are not renamed once published;
- registry symbols are not silently removed;
- compatibility-level downgrades must be documented as known issues or release notes;
- new supported app-visible behavior needs conformance coverage before it is advertised.

Use `cider compatibility-docs` to regenerate the registry and `cider alpha-readiness` to inspect the Stage 5 gate status.
