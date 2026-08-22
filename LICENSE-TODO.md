# License: not yet selected

**This repository has no license.** No license file is included because the
project owner has not chosen one.

## What that means right now

Under default copyright, absence of a license means **all rights reserved**.
Nobody has permission to use, copy, modify or distribute this code, regardless
of the fact that it is readable. That is not the intended end state — Cider is
meant to be open source — but it is the state today, and inventing a license to
paper over it would be worse than saying so.

Practical consequences:

- **Do not depend on this repository** in anything you ship or distribute.
- **Outside contributions cannot be accepted**, because there is nothing for a
  contributor to grant rights under.
- **No release, binary or otherwise, may be published** until a license is
  selected.

## What has to happen before a public release

`docs/01-project-charter.md` section 8 and
`docs/07-legal-distribution-boundaries.md` section 11 both make this a gate:

1. Select the project license.
2. Choose a contribution mechanism — a Developer Certificate of Origin workflow
   or a contributor license agreement.
3. Audit every dependency's license and record the obligations
   (`docs/07-legal-distribution-boundaries.md` section 8).
4. Confirm the project name and trademark language.
5. Replace this file with the chosen `LICENSE`, and update `README.md` and
   `CONTRIBUTING.md`.

## Considerations for whoever chooses

This is context, not advice. The choice belongs to the project owner, with
qualified counsel.

- **Cider ships no Apple code**, so nothing about that constrains the choice.
- **Runtime dependencies are all system libraries** resolved through pkg-config
  rather than vendored:

  | Library | License | Used by |
  | --- | --- | --- |
  | libX11 | MIT-style (X11) | `CX11Shim` |
  | FreeType | FTL or GPLv2, dual-licensed (FTL is permissive) | `CTextShim` |
  | fontconfig | MIT-style | `CTextShim` |

  None of these is copyleft in a way that reaches Cider's own sources, but the
  FreeType dual license carries an attribution requirement that a distribution
  has to honour.
- **A permissive license** (Apache-2.0, MIT) suits a compatibility runtime meant
  to be embedded in other people's development workflows. Apache-2.0
  additionally carries an explicit patent grant, which is worth weighing for a
  project in this space.
- **A weak-copyleft license** (MPL-2.0) would keep improvements to Cider's own
  files open while leaving applications built with it unaffected.
- **A strong-copyleft license** (GPL) would likely be self-defeating here, since
  applications link `CiderUI`.

Whatever is chosen should be stated in the README before the repository is made
public.
