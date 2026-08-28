# Stage 5 Alpha Readiness

Stage 5 is not just another feature stage. It is the point where Cider stops being only an internal prototype and becomes usable by outside experimental developers.

Run the live gate report with:

```sh
cider alpha-readiness
```

The report checks the current checkout for the Stage 5 gates from `docs/05-implementation-roadmap.md`:

- installation packaging;
- versioned compatibility contract;
- security reporting;
- contribution policy;
- known-issues database;
- performance baseline;
- at least 10 reference applications;
- CI on supported Ubuntu versions.

## Current interpretation

Most gates are **partial**, not done. That is the honest alpha-track state:

- source installation is documented, but signed/package-manager distribution is not shipped;
- compatibility contract `0.1` is documented, but it still needs an alpha tag/release note;
- security/contribution docs exist, but public contact/license decisions remain gates;
- known issues and performance baseline documents exist, but real public baseline numbers still need to be recorded;
- CI currently exercises the implemented matrix but must expand if Cider claims more than one supported Ubuntu version;
- the reference-app count is below the Stage 5 target of 10.

Do not mark Stage 5 complete until the readiness report has no `missing` gates and every `partial` gate has either been completed or explicitly accepted as an alpha caveat in release notes.
