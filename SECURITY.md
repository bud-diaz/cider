# Security Policy

## Supported versions

Cider is **pre-alpha / alpha-track**. There is no released version, no packaged
binary, and no support window. Only the current `main` branch is maintained.

Do not run Cider on untrusted input or in a security-sensitive environment. It
executes developer-supplied Swift code in-process with no sandbox beyond what the
host operating system provides by default.

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

> **A security contact address has not been published yet.** Cider is pre-alpha
> and has no public contribution channel;
> `docs/01-project-charter.md` section 8 makes establishing one a gate before
> public release. Until then, report directly to the project owner.

A useful report includes:

- what the vulnerability is, and what an attacker gains;
- the affected component and commit;
- steps to reproduce, ideally a minimal case;
- your assessment of severity;
- whether it is already public.

You will get an acknowledgement, an assessment, and credit when a fix ships,
unless you prefer otherwise. Please give a reasonable window to fix before public
disclosure.

## What Cider considers a vulnerability

The security model in `docs/03-technical-architecture.md` section 8 assumes
developer-owned code but still isolates applications. Against that model:

**In scope**

- Escaping an application's data root, or path traversal out of it.
- Bypassing a capability the manifest denied — reaching the network when
  `permissions.network: false`, for instance.
- A crafted `Cider.yaml`, launch descriptor or device profile causing memory
  corruption or arbitrary code execution in the toolchain or runtime.
- Memory-safety bugs in the C shims (`CX11Shim`, `CTextShim`) reachable from
  untrusted input, including malformed font data.
- A developer inspection interface binding to a non-local address.
- Secrets appearing in logs that Cider generates.
- Anything in the build path that executes code from a project without the
  developer's intent.

**Not in scope**

- Developer application code doing what it was written to do. Cider runs the code
  you give it.
- Crashes in a developer's own application.
- Denial of service from a local application consuming local resources.
- Vulnerabilities in system libraries (libX11, FreeType, fontconfig) — report
  those upstream, though tell us if Cider's use makes one reachable in an
  unusual way.
- Missing hardening that is on the roadmap and documented as absent. Stronger OS
  sandboxing is Stage 3+ work.

## Known limitations

Stated plainly so nobody has to discover them:

- **No OS-level process sandbox.** An application runs with the privileges of the
  user who launched it. Cider's project-owned Stage 3 services enforce network
  and local-storage permissions and scope file APIs to per-application data roots,
  but arbitrary developer Swift code still executes as local user code.
- **The C shims handle untrusted font data.** FreeType parses fonts resolved from
  the host's fontconfig database. They are compiled clean under `-Wall -Wextra`
  and copy defensively, but they have not been fuzzed.
- **The developer inspection interface is local-only.** `cider dev` binds to
  loopback and captures only Cider-owned runtime/service traffic; it is not a
  hardened remote administration surface.
- **No supply-chain verification.** Cider has no package dependencies today; when
  it does, the dependency policy in
  `docs/07-legal-distribution-boundaries.md` section 8 applies.

## Security-relevant boundaries

Cider does not implement, and will not accept contributions implementing,
anything whose purpose is to bypass code signing, DRM, device activation, or
platform security controls. See
[`docs/07-legal-distribution-boundaries.md`](docs/07-legal-distribution-boundaries.md)
section 4.
