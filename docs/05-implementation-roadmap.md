# Implementation Roadmap

## Stage 0 --- Research and Risk Retirement

**Goal:** Prove the project is technically worth implementing.

Spikes:

1.  Compile/run Swift on baseline Ubuntu.
2.  Call a project-owned native host service from Swift.
3.  Open a host window and render text/geometry.
4.  Deliver pointer events into Swift application code.
5.  Compile a minimal application through the proposed CLI path.
6.  Evaluate text/layout/graphics candidates.
7.  Document legal provenance for compatibility research.

**Exit:** A disposable demo renders an interactive Swift-defined button
in a Linux window without proprietary Apple runtime files.

## Stage 1 --- Runtime Skeleton

Build:

-   repository structure;
-   CI;
-   CLI skeleton;
-   manifest;
-   lifecycle;
-   device profile;
-   logging;
-   sandbox;
-   host abstraction interfaces;
-   Linux backend.

**Exit:** Hello application launches reproducibly from one CLI command.

## Stage 2 --- UI MVP

Implement:

-   normalized UI tree;
-   layout;
-   text;
-   image;
-   button;
-   stacks;
-   scrolling;
-   text input;
-   list;
-   navigation;
-   modal presentation;
-   screenshot testing.

**Exit:** UI reference apps pass deterministic conformance and visual
regression tests.

## Stage 3 --- Application Services

Implement:

-   HTTP/HTTPS;
-   preferences;
-   documents/cache/temp storage;
-   timers;
-   environment values;
-   clipboard;
-   lifecycle simulation;
-   basic permission model.

**Exit:** Notes and REST-client reference applications work end to end. This is
covered by conformance tests plus `scripts/validate-stages3-4.sh`, which builds
both apps, runs them under Xvfb through the real X11 backend, types/saves in
Notes, and clicks through the REST client to an HTTP 200 response.

## Stage 4 --- Developer Experience

Implemented developer-experience surfaces:

-   compatibility scanner (`cider scan`);
-   actionable unsupported-API diagnostics (`CID0605` from the scanner);
-   inspector (`cider inspect` project/manifest/sandbox/scan report, plus
    `cider run --inspect` runtime tree dumps);
-   network viewer (`cider network`);
-   storage viewer (`cider storage`);
-   rebuild/relaunch optimization (`cider dev-loop`, documenting
    `swift build` + `cider run --no-build`);
-   graphical local developer console (`cider dev`) with structured inspector
    snapshots, file-watching rebuild/relaunch, request capture for `CiderHTTP`,
    sandbox browser/reset, and event timeline;
-   templates (`cider init`);
-   documentation generator from compatibility registry
    (`cider compatibility-docs`).

**Exit:** A new contributor can create a template, run a sample, modify it,
scan for unsupported calls, inspect the project/runtime graphically, view
network/storage state, iterate through file-watching rebuild/relaunch, and
regenerate compatibility docs from published commands. This contributor flow is
covered by `scripts/validate-stages3-4.sh`.

## Stage 5 --- Alpha

Stage 5 is now in progress. The first alpha-readiness slice adds a versioned
compatibility contract (`docs/alpha-compatibility-contract.md`), alpha readiness
reporting (`cider alpha-readiness`), source-install documentation, a known-issues
database, and a performance-baseline document. These make the remaining public
alpha gates visible, but they do not by themselves complete Stage 5.

Requirements:

-   installation packaging;
-   versioned compatibility contract;
-   security reporting;
-   contribution policy;
-   known-issues database;
-   performance baseline;
-   at least 10 reference applications;
-   CI on supported Ubuntu versions.

**Exit:** Public alpha suitable for experimental developer use.

## Stage 6 --- Windows Backend

Port the host abstraction layer while keeping application compatibility
code shared.

**Exit:** Core conformance suite passes on both supported hosts.

## Post-MVP Candidates

Prioritize from real usage:

-   richer animation;
-   media playback;
-   WebView strategy;
-   accessibility bridge;
-   location simulation;
-   notification simulation;
-   rotation/tablet profiles;
-   IDE integrations;
-   VS Code extension;
-   remote physical-device testing;
-   optional macOS differential testing;
-   broader source compatibility.

## Explicitly Deferred

-   arbitrary App Store application execution;
-   iOS firmware boot;
-   hardware-faithful iPhone emulation;
-   DRM;
-   Apple signing bypass;
-   Secure Enclave replication.

## Stop/Go Review

After Stage 2, reassess:

-   performance;
-   API implementation cost;
-   legal risk;
-   contributor traction;
-   renderer quality;
-   whether source compatibility or a project-owned API should remain
    the dominant strategy.

Do not let sunk-cost energy turn the project into "emulate all of
Apple."
