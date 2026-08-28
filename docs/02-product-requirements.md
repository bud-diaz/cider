# Product Requirements Document

## 1. Product Summary

The product is a Linux-first local development environment for Swift
applications that use a supported iOS-compatible programming model.

The MVP consists of:

-   CLI toolchain;
-   compatibility framework;
-   host runtime;
-   virtual-device window;
-   debugger/logging hooks;
-   conformance examples and tests.

## 2. Core User Journey

A developer should be able to:

1.  Install the runtime and supported Swift toolchain.
2.  Open or create a compatible project.
3.  Run a project validation command.
4.  Build the application for the host runtime.
5.  Launch it in a selected virtual-device profile.
6.  Interact with the application.
7.  Inspect logs, requests, storage, and runtime warnings.
8.  Edit source and relaunch quickly.
9.  Use a Mac or macOS CI only when actual iOS
    compilation/signing/device validation is required.

## 3. MVP Functional Requirements

### FR-001: CLI

Provide commands equivalent in responsibility to:

-   initialize compatible sample project;
-   inspect compatibility;
-   build;
-   run;
-   test;
-   list device profiles;
-   select device profile;
-   print runtime diagnostics.

Command names are intentionally not frozen by this document.

### FR-002: Application Lifecycle

The runtime must define deterministic states for:

-   process start;
-   application initialization;
-   foreground;
-   background simulation;
-   termination;
-   relaunch.

### FR-003: Virtual Device

The shell must provide:

-   configurable logical resolution;
-   safe-area metadata;
-   portrait orientation at MVP;
-   mouse/pointer mapped to touch;
-   keyboard input;
-   configurable status-area simulation;
-   screenshot capture for testing.

### FR-004: UI

Initial primitives:

-   text;
-   image;
-   button;
-   vertical/horizontal stacks;
-   scroll container;
-   text input;
-   simple list;
-   navigation stack;
-   modal/presentation surface;
-   basic spacing, sizing, alignment, opacity, clipping, and corner
    radius.

### FR-005: Networking

Support standard application HTTP/HTTPS use cases through a
project-owned abstraction mapped to host networking.

Developer tooling should expose request method, destination, status,
duration, and errors without logging secrets by default.

### FR-006: Storage

Provide sandboxed per-application:

-   documents;
-   cache;
-   preferences/key-value storage;
-   temporary storage.

The sandbox must be inspectable and resettable from developer tooling.

### FR-007: Diagnostics

Unsupported framework calls must generate structured diagnostics
containing:

-   API identifier;
-   compatibility status;
-   source location when available;
-   suggested alternative or tracking issue when known.

### FR-008: Hot Development Loop

The architecture should target incremental rebuild/relaunch behavior.
True hot reload is desirable but not an MVP blocker.

## 4. Non-Functional Requirements

### Performance

Reference applications should launch in under two seconds on the
baseline development machine after build artifacts are warm. The project
should track build and launch latency from the first alpha.

### Determinism

Device profiles, layout inputs, and simulated system state must be
reproducible in CI.

### Security

Applications execute with least privilege feasible on the host. Runtime
storage is isolated by app identifier. Developer inspection interfaces
must bind locally by default.

### Portability

Host-specific services must sit behind explicit interfaces so Windows
support does not require rewriting application compatibility logic.

### Accessibility

Project-owned UI primitives should carry semantic roles from the
beginning, even if full assistive-technology integration arrives later.

## 5. MVP Reference Applications

Stage 5 requires at least 10 reference applications
(`docs/05-implementation-roadmap.md`). The conformance suite should include
at minimum, each mapped to its `examples/` directory:

-   Hello UI -- `examples/hello-cider`;
-   navigation/list app -- `examples/nav-list-cider`;
-   form/text-input app -- `examples/form-input-cider`;
-   image-loading app -- `examples/image-loading-cider`;
-   REST client -- `examples/rest-client-cider`;
-   persistent notes app -- `examples/notes-cider`;
-   modal/presentation example -- `examples/modal-presentation-cider`;
-   lifecycle/background simulation example -- `examples/lifecycle-cider`;
-   timer/clipboard service example -- `examples/timer-clipboard-cider`;
-   combined UI showcase -- `examples/ui-showcase`, which deliberately
    re-composes navigation, list, form/text-input, image-loading and modal
    presentation into one app (a documented Stage 2 B9 deviation; see
    `HANDOFF.md`) rather than duplicating those four as narrow examples a
    second time.

## 6. Not a Compatibility Promise

Passing in this runtime means an application conforms to the project's
documented compatibility behavior. It does not certify behavior on
physical Apple devices or Apple's simulator.
