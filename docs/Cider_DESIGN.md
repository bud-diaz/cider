# Cider — Brand Design Specification

**Status:** Locked    
**Direction:** Direction 1 — **The Press**    
**Brand:** Cider    
**Primary use:** Developer tooling, compatibility/runtime infrastructure, CLI, desktop tooling, documentation, web presence, repository assets

---

## 1. Brand Idea

Cider is an open-source compatibility runtime and development environment for building, running, and testing iOS-style Swift applications on Linux, with Windows support planned later.

The brand should communicate:

> **iOS-style development escaped the Mac.**

Cider should feel like serious developer infrastructure with a slightly rebellious edge.

The identity must not look like:

- an Apple parody;  
- a Hackintosh utility;  
- a fruit/beverage brand;  
- a generic Linux tool;  
- a clone of Xcode or Swift branding.

The visual language should feel:

- technical;  
- sharp;  
- precise;  
- modern;  
- open;  
- slightly unconventional;  
- mature enough to sit beside tools such as LLVM, Rust, Docker, Swift, and other serious developer platforms.

---

## 2. Locked Logo Direction

The official logo direction is:

# **The Press**

The logo is an abstract interpretation of a cider press combined with the architecture of the Cider runtime.

Conceptually:

```text  
Swift application  
        ↓  
      Cider  
        ↓  
   Linux / host  
```

The symbol should visually imply:

- compression;  
- translation;  
- layered execution;  
- input passing through a compatibility layer;  
- output emerging on the host platform.

The mark is not intended to depict a literal mechanical cider press.

It is a compact, geometric developer-tool symbol.

---

## 3. Logo Anatomy

The primary mark is built around a geometric **C-shaped frame**.

Inside the frame is a **downward arrow**.

A small top element and small base element reinforce the subtle press metaphor.

Conceptual structure:

```text  
        ■  
    ┌─────────  
    │  
    │    ↓  
    │  
    └─────────  
        ▲  
```

The final mark should feel balanced and architectural rather than illustrative.

### Meaning

| Element | Meaning |  
|---|---|  
| `C` frame | Cider |  
| upper block | source application / input |  
| downward arrow | translation / execution pipeline |  
| surrounding frame | compatibility layer |  
| lower block/base | host output |  
| vertical movement | app passing through Cider |

The symbol should still work even when the viewer knows none of this.

It must first succeed as a strong geometric mark.

The metaphor is secondary.

---

## 4. Shape Language

Cider should use a geometric, engineered visual language.

### Preferred traits

- thick strokes;  
- compact proportions;  
- subtly rounded corners;  
- strong horizontal structure;  
- clean negative space;  
- near-symmetry without feeling sterile;  
- simple enough to render clearly at favicon size.

### Avoid

- thin hairline strokes;  
- decorative curves;  
- hand-drawn shapes;  
- excessive gradients inside the core logo;  
- overly soft rounded forms;  
- cartoon styling;  
- skeuomorphic machinery;  
- literal fruit imagery.

The logo must remain recognizable in solid monochrome.

---

## 5. Primary Logo Configuration

The preferred horizontal lockup is:

```text  
\[PRESS MARK\] | C I D E R  
```

Use the icon to the left of the wordmark.

A subtle divider may be used in presentation, marketing, and UI contexts, but it is not mandatory.

### Preferred hierarchy

```text  
MARK      WORDMARK  
 30%        70%  
```

The symbol should have enough visual weight to stand independently.

---

## 6. Wordmark

The official wordmark is:

# **CIDER**

Use uppercase letters.

The wordmark should have:

- geometric construction;  
- moderate-to-wide tracking;  
- technical character;  
- clean terminals;  
- minimal personality beyond precision.

Approximate visual character:

```text  
C I D E R  
```

The spacing is part of the identity.

Do not compress the letters tightly.

### Typography direction

For product/UI typography, use a modern grotesk or geometric sans.

Recommended candidates:

1. **Inter**  
2. **Geist**  
3. **IBM Plex Sans**  
4. **Space Grotesk**  
5. **Söhne-style geometric grotesks**, where licensing permits

Preferred starting point:

```text  
UI / Docs: Inter or Geist  
Code: JetBrains Mono  
```

The final custom logo wordmark does not need to use the exact UI font.

---

## 7. Core Color Palette

The official Cider palette is warm, technical, and high-contrast.

### Primary Amber

**Cider Amber**

```text  
#E89A2F  
```

Usage:

- primary logo;  
- key brand moments;  
- selected UI states;  
- launch graphics;  
- highlights;  
- terminal accents;  
- documentation callouts.

### Bright Amber

```text  
#FFB547  
```

Usage:

- hover states;  
- highlights;  
- glow;  
- active controls;  
- gradients paired with Cider Amber.

Do not use Bright Amber as the default base color everywhere.

It should feel energized, not fluorescent.

### Near Black

```text  
#10100F  
```

Primary dark background.

### Graphite

```text  
#1C1C1A  
```

Secondary surfaces.

### Warm White

```text  
#F5F1E8  
```

Primary light foreground and light-background tone.

Avoid stark pure white when warm white works.

---

## 8. Extended UI Neutrals

Recommended UI expansion:

```css  
--cider-black:       #10100F;  
--cider-graphite:    #1C1C1A;  
--cider-surface:     #242421;  
--cider-border:      #34342F;  
--cider-muted:       #8F8D86;  
--cider-text:        #F5F1E8;  
--cider-amber:       #E89A2F;  
--cider-amber-bright:#FFB547;  
```

These may be tuned during product implementation while preserving the overall visual relationship.

---

## 9. Brand Gradient

Gradients are allowed as presentation effects but should not replace the solid logo.

Preferred gradient:

```css  
linear-gradient(  
  135deg,  
  #FFB547 0%,  
  #E89A2F 55%,  
  #D87812 100%  
)  
```

Use for:

- large marketing logo;  
- hero graphics;  
- splash screens;  
- app icon experiments;  
- subtle lighting effects.

Do not require gradients for legibility.

The logo must always work as:

```text  
solid amber  
solid black  
solid white  
```

---

## 10. Monochrome Logo

Required versions:

### Dark-on-light

```text  
#10100F on #F5F1E8  
```

### Light-on-dark

```text  
#F5F1E8 on #10100F  
```

### Brand-on-dark

```text  
#E89A2F on #10100F  
```

The monochrome mark is considered equally official.

---

## 11. App Icon

The preferred app icon uses the Press mark centered inside a dark or amber square.

### Primary app icon

```text  
Background: #10100F  
Mark:       #E89A2F  
```

### Alternate

```text  
Background: #E89A2F  
Mark:       #10100F  
```

### Light alternate

```text  
Background: #F5F1E8  
Mark:       #10100F  
```

Corners may follow the native platform icon mask.

Do not permanently bake exaggerated rounded-square geometry into the core symbol itself.

---

## 12. Favicon / Small Icon

At very small sizes, simplify aggressively.

Minimum version should preserve:

- outer C shape;  
- downward arrow.

The top and base press details may be simplified or removed if they become visual noise below approximately 20 px.

Suggested tiers:

```text  
>= 48px   full Press mark  
24–47px   simplified Press mark  
\<= 20px   C + arrow micro-mark  
```

Clarity beats conceptual completeness.

---

## 13. Clear Space

Use the arrow shaft width as the base spacing unit, designated `X`.

Minimum clear space:

```text  
X around all sides of the mark  
```

For the full horizontal lockup:

```text  
1.5X around all outer edges  
```

Do not crowd the logo against:

- window edges;  
- cards;  
- text;  
- other logos;  
- badges;  
- screenshots.

---

## 14. Minimum Sizes

Recommended minimum display sizes:

### Standalone symbol

```text  
16 px digital  
8 mm print  
```

Use the simplified micro-mark at the smallest size.

### Horizontal logo

```text  
120 px digital  
30 mm print  
```

If the wordmark becomes unreadable, use the symbol alone.

---

## 15. Compatibility Status Language

Cider's amber identity naturally connects to compatibility and runtime diagnostics.

The product may use a status system such as:

```text  
● Supported  
● Partial  
● Unsupported  
```

However, do not make every compatibility state amber.

Recommended semantic approach:

```text  
Supported    → success semantic color  
Partial      → Cider Amber  
Unsupported  → error semantic color  
Unknown      → neutral gray  
```

Cider Amber should become especially associated with:

- translation;  
- partial compatibility;  
- runtime activity;  
- warnings that are actionable rather than catastrophic.

---

## 16. CLI Branding

The CLI should feel clean and restrained.

Example:

```text  
◆ CIDER

Building Demo...  
Runtime ready.  
Launching...  
```

Preferred use of amber:

```text  
◆  
CIDER  
active stage indicators  
warnings  
important paths or values  
```

Do not turn the terminal into a rainbow.

### Example `cider doctor`

```text  
Cider Doctor

Host                 Ubuntu 26.04  
Architecture         x86_64  
Swift                6.x ✓  
Compiler             Ready ✓  
Runtime              Ready ✓  
Graphics backend     Ready ✓

Cider is ready.  
```

Brand voice in CLI output should be concise and technical.

---

## 17. UI Direction

Cider UI should visually extend the logo system.

### Overall

```text  
dark  
technical  
precise  
low-noise  
warm accent  
```

### Background hierarchy

```text  
App background      #10100F  
Primary surface     #1C1C1A  
Secondary surface   #242421  
Borders             #34342F  
Primary text        #F5F1E8  
Secondary text      muted neutral  
Accent              #E89A2F  
```

### Corners

Use moderate radii.

Recommended range:

```text  
6–12 px  
```

Avoid extremely bubbly SaaS styling.

### Controls

Controls should feel:

- dense;  
- deliberate;  
- developer-first;  
- functional before decorative.

---

## 18. Visual Motifs

The following motifs may be derived from the logo:

### Downward movement

```text  
↓  
```

Use to imply:

- compile;  
- translate;  
- execute;  
- deploy into runtime;  
- resolve into host implementation.

### Compression bars

Horizontal layers can appear in:

- loading animations;  
- section dividers;  
- diagrams;  
- developer documentation.

### Layer diagrams

Architecture graphics may use the visual metaphor:

```text  
APP  
────  
CIDER  
────  
HOST  
```

This directly reinforces the brand concept.

---

## 19. Motion

Cider motion should be fast and purposeful.

Recommended timing:

```text  
micro interaction: 120–180ms  
standard UI:       180–260ms  
large transition:  260–360ms  
```

Avoid floaty spring-heavy motion.

### Logo animation concept

For splash screens or launch states:

1. top block appears;  
2. outer C frame resolves;  
3. arrow travels downward;  
4. base appears;  
5. wordmark fades or tracks into place.

The entire sequence should be brief.

The motion metaphor is:

> input → translation → output.

---

## 20. Photography / Illustration

Cider should not depend heavily on photography.

Preferred brand imagery:

- product screenshots;  
- architecture diagrams;  
- code;  
- terminal output;  
- abstract layered forms;  
- subtle device framing;  
- geometric 3D objects derived from the Press mark.

Avoid:

- apples;  
- cider glasses;  
- farms;  
- fruit photography;  
- literal cider presses;  
- generic hacker stock photos;  
- neon cyberpunk clichés.

---

## 21. Voice

Cider should sound technically confident without pretending the project does more than it actually does.

Voice attributes:

- concise;  
- capable;  
- slightly irreverent;  
- transparent about compatibility;  
- developer-native;  
- not corporate.

Good:

> Run Swift-style apps on Linux through the Cider compatibility runtime.

Good:

> Partial support. `NavigationStack` currently falls back to Cider's host navigation implementation.

Bad:

> Experience revolutionary cross-platform Apple innovation without limits.

We are not doing brochure crimes.

---

## 22. Relationship to Apple

Cider should maintain strong visual separation from Apple.

### Never use

- Apple logo silhouettes;  
- bitten fruit;  
- Apple leaf shapes;  
- rainbow Apple motifs;  
- San Francisco typography as an imitation device;  
- Xcode icon compositions;  
- Swift bird imitations;  
- macOS traffic-light motifs as branding;  
- phrases suggesting Cider is an official Apple product.

Cider can reference the Apple ecosystem descriptively where technically necessary, but its identity must stand independently.

---

## 23. Relationship to Linux

Linux is Cider's first host platform.

Linux is not the entire brand.

Do not make the logo:

- a penguin;  
- a terminal prompt;  
- a distro mascot parody;  
- Linux-green by default.

The architecture is intended to support other host platforms later.

Therefore:

> **Cider is the compatibility system. Linux is a backend.**

The brand must reflect that distinction.

---

## 24. Logo Misuse

Do not:

- rotate the mark;  
- skew it;  
- stretch it;  
- add drop shadows as part of the permanent logo;  
- outline the official mark unnecessarily;  
- place fruit inside the C;  
- replace the arrow with an Apple logo;  
- add `\</>` inside it;  
- add a terminal prompt inside it;  
- add a Linux penguin;  
- fill each logo segment with different colors;  
- use rainbow gradients;  
- place text inside the symbol;  
- over-round the geometry;  
- make the mark look like a beverage company.

And no apple with a terminal prompt in it.

Seriously.

---

## 25. Repository Branding

Suggested repository assets:

```text  
.github/  
└── assets/  
    ├── cider-logo-horizontal-dark.svg  
    ├── cider-logo-horizontal-light.svg  
    ├── cider-mark-amber.svg  
    ├── cider-mark-black.svg  
    ├── cider-mark-white.svg  
    ├── cider-icon.svg  
    └── cider-social-card.png  
```

README hero:

```text  
\[ CIDER PRESS MARK \]

C I D E R

Swift-style development.  
Open host.  
No Mac required for every iteration.  
```

Any claim about macOS requirements must remain technically accurate to Cider's actual capabilities.

---

## 26. Website Direction

Recommended landing-page structure:

```text  
CIDER  
↓  
Hero statement  
↓  
Interactive runtime demo / screenshot  
↓  
How the compatibility layer works  
↓  
Supported APIs  
↓  
CLI example  
↓  
Architecture  
↓  
Install / GitHub  
```

The Press metaphor may appear subtly through layered section transitions.

Do not build the whole site around cider/beverage jokes.

One joke is branding.

Twenty is a theme restaurant.

---

## 27. Core Design Tokens

```css  
:root {  
  --cider-black: #10100F;  
  --cider-graphite: #1C1C1A;  
  --cider-surface: #242421;  
  --cider-border: #34342F;

  --cider-white: #F5F1E8;  
  --cider-muted: #8F8D86;

  --cider-amber: #E89A2F;  
  --cider-amber-bright: #FFB547;

  --cider-radius-sm: 6px;  
  --cider-radius-md: 8px;  
  --cider-radius-lg: 12px;

  --cider-motion-fast: 150ms;  
  --cider-motion-standard: 220ms;  
  --cider-motion-large: 320ms;  
}  
```

---

## 28. Brand Test

Before approving any future Cider asset, ask:

### Does it feel like developer infrastructure?

If not, revise it.

### Does it look like an Apple parody?

If yes, kill it.

### Can the symbol survive at 16 × 16?

If not, simplify it.

### Does amber remain an accent rather than swallowing the interface?

If not, reduce it.

### Could this identity still make sense when Windows support arrives?

If not, it is too Linux-specific.

### Does the design imply translation, runtime, layers, or execution?

Ideally, yes.

---

## 29. Locked Decisions

The following decisions are considered canonical unless the brand is intentionally redesigned later:

```text  
Brand name:        Cider  
Logo direction:    The Press  
Primary color:     Cider Amber #E89A2F  
Highlight color:   Bright Amber #FFB547  
Dark background:   Near Black #10100F  
Secondary dark:    Graphite #1C1C1A  
Light foreground:  Warm White #F5F1E8  
Wordmark:          CIDER, uppercase, widely tracked  
Core metaphor:     application → translation → host  
Primary icon idea: geometric C / press + downward arrow  
```

---

## 30. One-Line Brand Definition

> **Cider is the compatibility layer that presses Swift-style applications through a portable runtime and into the host platform beneath them.**