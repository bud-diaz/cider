# Open iOS Runtime Project --- Pre-Implementation Documentation

## Purpose

This repository defines a proposed open development environment for
running and testing iOS-style applications on non-macOS hosts, beginning
with Linux and expanding to Windows.

The project is **not** intended to distribute iOS, reproduce an iPhone
firmware image, bypass Apple security controls, install App Store
applications, or replace Apple's signing and distribution
infrastructure.

The initial product goal is narrower:

> Give developers a fast local environment on Linux for building,
> running, inspecting, and testing applications written against a
> deliberately supported Swift/iOS-compatible API surface.

## Documentation Set

1.  `01-project-charter.md` --- mission, scope, stakeholders,
    principles, success criteria.
2.  `02-product-requirements.md` --- users, use cases, functional and
    non-functional requirements.
3.  `03-technical-architecture.md` --- runtime architecture,
    compiler/toolchain strategy, host abstractions, package layout.
4.  `04-compatibility-specification.md` --- compatibility tiers, API
    policy, app manifest, unsupported behavior.
5.  `05-implementation-roadmap.md` --- research spikes, MVP phases, exit
    criteria, post-MVP direction.
6.  `06-testing-strategy.md` --- unit, conformance, integration, visual,
    performance, and security testing.
7.  `07-legal-distribution-boundaries.md` --- clean-room principles,
    trademarks, proprietary assets, contributor rules.
8.  `Cider_DESIGN.md` --- locked brand/design specification: palette,
    logo direction, typography, UI direction, voice, and misuse rules.
9.  `Cider Branding.md` --- exploratory brand rationale that led to the
    locked design direction.

## Working Project Definition

**Category:** Developer tooling / compatibility runtime\
**Initial host:** Ubuntu Linux x86-64\
**Secondary host:** Windows x86-64\
**Primary language target:** Swift\
**Initial UI strategy:** Project-owned compatibility UI layer, with
progressively expanded source compatibility\
**Final Apple build:** Remains outside project scope and requires
Apple's supported toolchain where applicable.

## Pre-Implementation Gate

Implementation should not begin beyond disposable research spikes until:

-   the MVP compatibility target is frozen;
-   the first 10--20 conformance examples are written;
-   the legal/clean-room rules are adopted;
-   the architecture spike proves Swift code can call the host
    abstraction layer;
-   the UI rendering strategy is selected;
-   the repository license and contribution policy are selected.
