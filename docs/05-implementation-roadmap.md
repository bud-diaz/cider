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

**Exit:** Notes and REST-client reference applications work end to end.

## Stage 4 --- Developer Experience

Implement:

-   compatibility scanner;
-   actionable unsupported-API diagnostics;
-   inspector;
-   network viewer;
-   storage viewer;
-   rebuild/relaunch optimization;
-   templates;
-   documentation generator from compatibility registry.

**Exit:** A new contributor can install, run a sample, modify it, and
diagnose an unsupported call using published docs.

## Stage 5 --- Alpha

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
