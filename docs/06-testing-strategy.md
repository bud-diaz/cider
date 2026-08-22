# Testing Strategy

## 1. Objective

The test suite is the compatibility contract. Features are not
"supported" because a demo happened to work once.

## 2. Test Layers

### Unit Tests

Cover:

-   layout math;
-   lifecycle transitions;
-   manifest parsing;
-   sandbox path resolution;
-   compatibility registry;
-   event translation;
-   networking adapters;
-   storage semantics.

### Conformance Tests

Each supported application-facing behavior receives a stable conformance
ID.

Example:

``` text
UI-TEXT-001
UI-BUTTON-001
NAV-PUSH-001
NET-HTTP-001
STORE-PREF-001
LIFE-BG-001
```

A Level A compatibility claim requires passing conformance coverage.

### Integration Tests

Launch complete reference applications and verify user flows.

### Visual Regression

Render deterministic scenes and compare screenshots against
project-owned baselines.

Allow controlled tolerances for font rasterization and platform
differences.

### Performance Tests

Track:

-   clean build time;
-   incremental build time;
-   launch time;
-   first render;
-   memory use;
-   frame timing;
-   large-list behavior.

### Security Tests

Validate:

-   app sandbox separation;
-   path traversal resistance;
-   inspector binding;
-   log redaction;
-   manifest capability enforcement;
-   malformed project inputs.

## 3. Differential Testing

If the project later compares behavior against Apple's environment,
tests must use applications/source/assets the project is authorized to
use.

Differential results should be stored as measurements and descriptions,
not copied proprietary implementation material.

## 4. CI Matrix

Initial:

``` text
Ubuntu supported LTS
× Debug/Release runtime
× Swift supported version(s)
```

Windows is added when its backend enters active development.

## 5. Bug Classification

Compatibility bugs should identify:

-   API/domain;
-   expected project behavior;
-   observed behavior;
-   host;
-   runtime version;
-   device profile;
-   compatibility level;
-   minimal reproduction.

## 6. Release Gate

A release cannot promote an API to Level A without:

-   documented contract;
-   conformance tests;
-   passing CI;
-   known-differences review;
-   user-facing documentation.

## 7. Reference Application Policy

Reference apps must be small, source-controlled, and project-owned or
permissively licensed. Each should test a narrow capability before
larger showcase apps are introduced.
