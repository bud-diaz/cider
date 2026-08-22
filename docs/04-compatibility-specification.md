# Compatibility Specification

## 1. Purpose

Compatibility must be measurable. "Supports iOS apps" is too vague to
engineer against and too easy to oversell.

## 2. Compatibility Levels

Each API or behavior receives one status:

### Level A --- Compatible

Expected observable behavior matches the project's defined compatibility
contract for supported inputs.

### Level B --- Compatible With Differences

Usable, but documented differences exist in appearance, timing, platform
integration, or edge behavior.

### Level C --- Development Stub

API exists to permit development/testing but returns simulated or
restricted behavior.

### Level D --- Recognized, Unsupported

Tooling recognizes the API and emits a targeted diagnostic.

### Level X --- Not Implemented / Unknown

No compatibility guarantee.

## 3. MVP Compatibility Domains

  Domain                            MVP Target
  --------------------------------- ------------------------
  Swift language                    Host-supported
  Foundation-like basic utilities   Selective
  Application lifecycle             Project-compatible
  Declarative/basic UI              Selective
  Navigation                        Supported subset
  HTTP networking                   Supported subset
  Local files                       Supported subset
  Preferences                       Supported
  Touch/pointer                     Simulated
  Keyboard                          Supported
  Orientation                       Portrait first
  Camera                            Unsupported initially
  Bluetooth                         Unsupported initially
  Cellular                          Simulated/unsupported
  Push notifications                Development stub later
  StoreKit/purchases                Unsupported initially
  Secure Enclave                    Unsupported
  Apple account services            Unsupported

## 4. Source Compatibility Policy

The project may pursue familiar source shapes only where legally and
technically appropriate. It must not imply binary compatibility merely
because source code compiles.

Three distinct claims must remain separate:

-   **source compatibility**: code can compile with limited/no changes;
-   **behavioral compatibility**: documented behavior is equivalent
    enough for testing;
-   **binary compatibility**: an existing compiled binary can execute.

MVP targets the first two selectively. Arbitrary iOS binary
compatibility is not an MVP objective.

## 5. Unsupported API Behavior

Unsupported calls must never silently succeed with fabricated production
behavior.

Preferred modes:

-   compile-time diagnostic where detectable;
-   runtime structured exception/error;
-   explicit simulated value for documented development stubs.

## 6. Visual Compatibility

Pixel-perfect reproduction of Apple's UI is not an MVP goal.

Visual tests validate the project's own renderer for regressions. A
later optional macOS comparison suite may quantify differences against
developer-owned reference applications.

## 7. Versioning

Compatibility contracts follow semantic project releases.

Breaking changes to a previously Level A API require:

-   release-note disclosure;
-   migration guidance;
-   compatibility registry update;
-   test update;
-   major-version change once the project reaches 1.0.

## 8. Compatibility Scorecard

Every release should publish generated coverage by domain, including
counts for Levels A--D and known differences.

The project should never advertise a single misleading percentage such
as "80% iOS compatible" without explaining the denominator.
