# Technical Architecture

## 1. Architecture Goal

Separate application-facing compatibility APIs from host-specific
implementation so that Linux is the first backend, not a permanent
architectural assumption.

## 2. High-Level Model

``` text
Swift Application Source
          |
          v
Compatibility / Source Adaptation Layer
          |
          v
Application Runtime
   |      |       |
   |      |       +--> Diagnostics / Inspector
   |      +----------> Lifecycle / Sandbox
   +-----------------> UI + Services Interfaces
                          |
                    Host Abstraction Layer
                     /              \
              Linux Backend      Windows Backend
                   |
          Windowing / Graphics /
        Network / Filesystem / Input
```

## 3. Major Components

### A. Toolchain Front End

Responsibilities:

-   project discovery;
-   manifest parsing;
-   compatibility scan;
-   Swift build orchestration;
-   generated glue where required;
-   launch configuration;
-   test orchestration.

### B. Compatibility Framework

Contains project-owned types and behavior representing the supported
application programming model.

The framework must not depend on copied Apple implementation binaries.

Where source-level compatibility with familiar API shapes is pursued,
implementation must follow the project's legal and clean-room rules.

### C. Runtime Core

Responsibilities:

-   app lifecycle;
-   event loop;
-   service registry;
-   environment values;
-   device profile;
-   sandbox paths;
-   permissions simulation;
-   logging;
-   unsupported-API traps.

### D. UI Runtime

Use a retained or declarative internal tree that is independent from the
host renderer.

Suggested internal flow:

``` text
Application View Description
          ↓
Normalized UI Tree
          ↓
Layout Engine
          ↓
Render Tree
          ↓
Host Graphics Backend
```

This creates a testable seam between API compatibility and graphics.

### E. Host Abstraction Layer

Define interfaces for:

-   window;
-   graphics;
-   font/text;
-   pointer/touch;
-   keyboard;
-   clipboard;
-   network;
-   filesystem;
-   timers;
-   process;
-   accessibility;
-   media, later.

Linux and Windows implement these interfaces independently.

## 4. Initial Technology Decisions to Validate

Before freezing libraries, run spikes for:

1.  Swift-to-native Linux interoperability.
2.  Windowing and graphics backend candidates.
3.  Text shaping and font metrics.
4.  UI layout engine strategy.
5.  Swift package/project integration.
6.  debugger integration.
7.  Windows portability of selected dependencies.

No dependency should be chosen solely because it makes the first
screenshot easy if it makes Windows support structurally painful.

## 5. Project Manifest

A project-owned manifest should describe runtime metadata independently
of Apple's proprietary project formats.

Illustrative fields:

``` yaml
app:
  id: dev.example.notes
  name: Notes Example
  entry: NotesApp

runtime:
  minimumCompatibility: "0.1"
  device: phone-standard

permissions:
  network: true
  localStorage: true
```

The exact schema is to be versioned before alpha.

## 6. Device Profiles

A profile contains deterministic values such as:

-   logical width/height;
-   pixel scale;
-   safe-area insets;
-   orientation;
-   locale;
-   preferred text size;
-   light/dark appearance;
-   simulated battery/network state.

Profiles should use project-owned generic names by default rather than
Apple product branding.

## 7. Compatibility Registry

Every exposed compatibility API should have machine-readable metadata:

``` text
identifier
introduced_runtime_version
compatibility_level
known_differences
test_ids
documentation_url
```

This registry powers documentation, diagnostics, and project scans.

## 8. Security Model

MVP should assume developer-owned code but still isolate applications.

Preferred controls:

-   per-app data roots;
-   explicit capability declarations;
-   local-only inspector;
-   sanitized logs;
-   optional stronger OS sandboxing after the execution model
    stabilizes.

## 9. Repository Shape

``` text
/
├── cli/
├── compiler-support/
├── compatibility/
├── runtime/
├── ui/
├── host/
│   ├── linux/
│   └── windows/
├── device-profiles/
├── inspector/
├── examples/
├── tests/
│   ├── unit/
│   ├── conformance/
│   ├── integration/
│   └── visual/
└── docs/
```

## 10. Architectural Red Lines

Do not make core runtime behavior depend on:

-   an iOS firmware image;
-   Apple simulator runtime files;
-   undocumented copied system frameworks;
-   a remote Mac;
-   an Apple account;
-   App Store binaries.

A macOS validation service may exist later as an optional comparison
tool, but it must not become a hidden requirement for the Linux runtime.
