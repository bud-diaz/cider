# Legal and Distribution Boundaries

> This document establishes project engineering policy. It is not a
> substitute for advice from qualified counsel.

## 1. Objective

Build useful interoperability without making Apple proprietary software,
protected assets, credentials, or security circumvention part of the
product.

## 2. Distribution Rule

Official project releases must not bundle:

-   iOS firmware;
-   Apple simulator runtimes;
-   copied UIKit/SwiftUI/Foundation implementation binaries;
-   Apple SDK files not licensed for redistribution;
-   Apple certificates or credentials;
-   decrypted App Store applications;
-   proprietary Apple icons, fonts, device artwork, or other assets
    unless separately authorized.

## 3. Clean-Room / Provenance Policy

Compatibility implementations should be based on lawful sources such as:

-   public documentation;
-   observable behavior from developer-owned test programs;
-   standards;
-   permissively licensed/open-source code with compatible licensing;
-   independently authored tests and specifications.

Every imported dependency must have license metadata.

For sensitive compatibility work, maintain a short provenance note
describing the public behavior being implemented and the
sources/categories used.

## 4. Security Boundary

The project must not ship functionality whose purpose is to:

-   bypass Apple activation/security controls;
-   defeat code signing;
-   defeat DRM;
-   access Apple accounts without authorization;
-   circumvent device locks;
-   impersonate Apple services.

Research required for lawful interoperability should be isolated from
product features and reviewed before merge when it touches security
mechanisms.

## 5. Branding

Use a distinct project name, logo, device shell, and generic
device-profile names.

References to Apple, iOS, iPhone, UIKit, SwiftUI, Xcode, and related
marks should be descriptive and should not imply sponsorship,
certification, or affiliation.

Public-facing naming and trademark language should receive legal review
before launch.

## 6. API Naming

Reimplementing behavior and reproducing API names can raise different
copyright, trademark, license, and jurisdiction-specific questions.

Before committing to broad drop-in source compatibility with proprietary
framework APIs, obtain project-specific legal review.

Until then:

-   keep the internal architecture independent;
-   maintain project-owned abstractions;
-   treat source-compatibility shims as replaceable modules;
-   do not copy proprietary headers or implementation code into the
    repository.

## 7. Contributor Requirements

Contributors should certify that they have the right to submit their
work.

Before public contributions open, choose either:

-   Developer Certificate of Origin workflow; or
-   contributor license agreement.

Contribution guidelines should prohibit proprietary Apple code/assets
and require disclosure of copied/adapted third-party material.

## 8. Dependency Policy

Every dependency must record:

-   package/repository;
-   version;
-   license;
-   purpose;
-   source;
-   redistribution obligations.

Copyleft dependencies are not automatically prohibited, but their
implications must be understood before adoption.

## 9. User-Supplied Apple Materials

The MVP should not require users to supply Apple firmware/framework
files.

If a future optional feature contemplates user-supplied proprietary
material, that feature requires a separate legal and architectural
review before implementation.

## 10. Marketing Claims

Avoid:

-   "official iOS emulator";
-   "runs all iPhone apps";
-   "Xcode replacement";
-   "100% iOS compatible."

Prefer precise language describing the tested compatibility subset and
development purpose.

## 11. Pre-Public-Release Legal Gate

Before a public binary release:

1.  review project/product name;
2.  review license;
3.  review dependency licenses;
4.  audit repository for proprietary files/assets;
5.  review compatibility API strategy;
6.  review website/README claims;
7.  document takedown/security contact;
8.  obtain qualified legal advice if broad Apple-framework source
    compatibility is being shipped.
