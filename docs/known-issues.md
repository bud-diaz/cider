# Known Issues

This is the Stage 5 alpha-track known-issues database. It records user-visible limitations that should be visible before someone tries Cider, even when they are not security vulnerabilities.

| ID | Area | Status | Impact | Workaround / Next step |
| --- | --- | --- | --- | --- |
| CIDER-KI-0001 | UI showcase manual polish | Open | `examples/ui-showcase` builds and primitives are tested, but the full app has not had an exhaustive human tap-through pass under `cider run`. | Run and record a manual UX pass before public alpha. |
| CIDER-KI-0002 | Text input | Open | X11 basic text input works for simple keymap text, but full XIM/XIC/IME composition and dead keys are not implemented. | Use ASCII/basic text while running under Cider; implement composed input before claiming broader text support. |
| CIDER-KI-0003 | Compatibility scanner | Open | `cider scan` is token-based, not a Swift parser. It can miss dynamic/aliased framework usage and only knows registered symbols. | Keep registry entries explicit; consider SwiftSyntax when scanner precision becomes a blocker. |
| CIDER-KI-0004 | Dev console proxy scope | Open | `cider dev` request capture is loopback-only and scoped to `CiderHTTP`; it is not a system-wide proxy. | Use `CiderHTTP` in reference apps for inspectable network calls. |
| CIDER-KI-0005 | File watching | Open | The dev console uses polling and rebuild/relaunch, not in-process Swift hot swap. | Use `cider run --no-build` and `cider dev` for faster loops; do not expect hot reload. |
| CIDER-KI-0006 | Reference app count | Open | Stage 5 requires at least 10 reference applications; fewer exist today. | Add distinct reference apps and keep them building in CI. |
| CIDER-KI-0007 | Public packaging | Open | Cider has no signed binary archive or package-manager distribution yet. | Build from source per `docs/install.md` until packaging lands. |
| CIDER-KI-0008 | Security contact | Open | `SECURITY.md` exists, but no durable public security contact is published yet. | Publish contact before public alpha. |
