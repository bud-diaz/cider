# Design Spec: Dev Tool Landing Page (Hero + Features)

**Source:** 21st.dev — `@mokshithcodez/dev-tool-landing-page`
**Stack:** React + TypeScript, Tailwind CSS, Framer Motion, lucide-react
**Component export:** `Component` (named), also default export

---

## 1. Overview

A dark-themed developer-tool landing page section made of two full-viewport blocks:

1. **Interactive Code Hero** — split layout with a headline/walkthrough on the left and a live, hoverable code editor mock on the right.
2. **Claim & Proof Features** — a stacked list of three feature rows, each pairing a plain-language claim with a "proof" panel styled like a terminal/inspector output that reveals on hover.

The overall tone is technical, minimal, and IDE-inspired — dark backgrounds, monospace code blocks, muted zinc grays, and small saturated accent colors (rose, amber, emerald) used sparingly to signal state or category.

---

## 2. Design Tokens

### 2.1 Color Palette

| Token | Value | Usage |
|---|---|---|
| Background (page) | `#09090b` (zinc-950) | Root container background |
| Background (panel) | `#111115` | Card/panel surfaces, terminal header bar |
| Background (panel deep) | `#0d0d0f` | Code editor body, proof-panel body |
| Background (panel hover) | `#15151a` | Feature row hover state |
| Border (default) | `zinc-800` / `zinc-800/50` / `zinc-800/80` | Card borders, dividers |
| Border (hover) | `zinc-700` | Card/row hover border |
| Text (primary) | `white` / `zinc-100` | Headlines, feature titles |
| Text (body) | `zinc-400` | Paragraph copy |
| Text (muted) | `zinc-500` | Labels, line numbers, secondary code text |
| Text (dim) | `zinc-600` | Line-number gutter |
| Accent — Rose | `rose-400` / `rose-500` | Primary accent: active line indicator, headless-accessibility feature, text selection color |
| Accent — Amber | `amber-400` | Types/TypeScript feature, JSX-token syntax highlight |
| Accent — Emerald | `emerald-400` / `emerald-300/90` | Runtime feature, string syntax highlight, success/checkmark states |
| Selection color | `rose-500/30` | `::selection` styling via `selection:bg-rose-500/30` |

**Syntax highlighting map (code block tokens):**
- Keywords (`import`, `from`, `return`) → `text-rose-400`
- Identifiers / JSX tags / braces (`Component`, `export default function`, etc.) → `text-amber-400`
- String literals → `text-emerald-300/90`
- Punctuation (semicolons) → `text-zinc-500`
- Comments → `text-zinc-500`

### 2.2 Typography

| Element | Classes | Notes |
|---|---|---|
| Hero H1 | `text-3xl md:text-4xl font-semibold text-white tracking-tight` | "Zero-config previews." |
| Section H2 | `text-2xl md:text-3xl font-semibold text-white tracking-tight` | "Engineered for constraints." |
| Feature title (H3) | `text-lg font-medium text-zinc-100` | |
| Body copy | `text-sm md:text-base text-zinc-400 leading-relaxed` | |
| Eyebrow / badge | `text-xs font-medium text-zinc-400` | Pill badge, e.g. "Integration" |
| Overline label | `text-xs font-medium text-zinc-500 uppercase tracking-wider` | "Walkthrough" |
| Proof panel label | `text-[10px] uppercase tracking-widest text-zinc-500 font-semibold` | e.g. "Build Output" |
| Code / monospace | `font-mono text-sm` (editor), `font-mono text-xs` (proof panel) | `leading-loose` in editor for line spacing |
| Base font | `font-sans` on root wrapper | Inherits Tailwind's default sans stack |

### 2.3 Spacing & Layout

- Page sections are each `min-h-screen`, so the component behaves like two full-height scroll snaps rather than compact blocks.
- Hero section padding: `p-6 md:p-12`; content capped at `max-w-4xl`.
- Features section padding: `p-6 md:p-12 lg:p-24`; content capped at `max-w-5xl`.
- Hero grid: `grid-cols-1 lg:grid-cols-12` → left column `lg:col-span-5`, right column `lg:col-span-7`, `gap-8`.
- Feature rows: vertical stack, `space-y-4`, each row is `flex-col md:flex-row` (stacks on mobile, splits claim/proof side-by-side on desktop).
- Proof panel fixed width on desktop: `md:w-80`.

### 2.4 Radius, Borders, Shadows

- Cards/panels: `rounded-xl` (editor window) or `rounded-2xl` (feature rows).
- Badge pill: `rounded-full`.
- Borders are hairline (`border`) using zinc-800 variants at partial opacity for subtlety.
- Hero code panel has a soft blurred glow behind it: `absolute -inset-0.5 bg-gradient-to-b from-zinc-800 to-zinc-900 rounded-2xl blur opacity-30 group-hover:opacity-50` — a classic "card glow" effect that intensifies on hover.
- Feature rows get a colored drop-shadow glow on hover, unique per feature (`group-hover:shadow-[0_0_30px_-5px_rgba(...)]`), tinted to that feature's accent color (emerald / amber / rose at 15% opacity).

---

## 3. Section 1 — Interactive Code Hero

### 3.1 Purpose
Communicates the product's core value prop ("zero-config previews") while demonstrating it live: hovering a numbered walkthrough step highlights the corresponding line in a fake code editor.

### 3.2 Structure

**Left column (`lg:col-span-5`):**
1. Badge: pill with `Terminal` icon + "Integration" label.
2. H1: "Zero-config previews."
3. Supporting paragraph (2 sentences, ~30 words).
4. "Walkthrough" overline label.
5. Three interactive step buttons, each tied to a code line number (5, 8, 9) with a short explanation string from the `EXPLANATIONS` map.

**Right column (`lg:col-span-7`):**
A mock code editor window:
- Header bar: three inert "traffic light" dots (all zinc, not colored — intentionally muted, non-functional decoration), a filename chip (`FileCode2` icon + "demo.tsx"), and a copy button on the right.
- Body: line-numbered, syntax-highlighted code block rendering the `DEMO_CODE` array (11 lines including comments and blank lines).

### 3.3 Interaction Design

**Hover-linked highlighting (the centerpiece interaction):**
- State: `activeLine: number | null`, set via `onMouseEnter`/`onMouseLeave` on the three walkthrough buttons.
- When a walkthrough button is hovered:
  - That button gets a highlighted background (`bg-zinc-900/80`), border (`border-zinc-700`), shadow, and its line-number badge switches from zinc to rose (`border-rose-500 text-rose-400`).
  - The corresponding code line in the editor gets a `layoutId="active-line-bg"` animated background bar (Framer Motion `AnimatePresence`) — a left-bordered highlight strip (`border-l-2 border-rose-400`, `bg-zinc-800/40`) that spans the full row width using negative margin (`-inset-x-4`).
  - All *other* code lines dim to `opacity: 0.3` (200ms transition) via a wrapping `motion.div` on every line — so the effect is "spotlight" style, not just an added highlight.
- `layoutId` means the highlight bar physically animates (slides) between lines rather than fading in fresh each time — this is a deliberate, notable motion choice.

**Copy button:**
- Click toggles `isCopied` state → icon swaps from `Copy` to `Check` (emerald) for 2 seconds via `setTimeout`, then reverts.
- **Note for implementation:** the button does not currently write anything to the clipboard — it only manages the icon state. A real integration should add `navigator.clipboard.writeText(...)` with the actual code string.

**Traffic-light dots:** decorative only, no click handlers, all rendered in the same muted zinc tone (not red/yellow/green) — an intentional "flattened," design-system-consistent take on the macOS window control motif rather than a literal skeuomorphic reference.

### 3.4 Responsive Behavior
- Stacks to a single column below `lg` breakpoint (code editor moves below the text column).
- Padding steps down from `p-12` to `p-6` on mobile.
- Headline steps from `text-4xl` to `text-3xl`.

---

## 4. Section 2 — Claim & Proof Features

### 4.1 Purpose
Three-item feature list that pairs an abstract claim ("Zero-runtime overhead") with a concrete, technical "proof" artifact (a fake build log, a fake TypeScript error, a fake DOM inspector snippet) — reinforcing credibility through simulated tooling output rather than marketing copy alone.

### 4.2 Structure
Section header:
- H2: "Engineered for constraints."
- Supporting paragraph, max-width constrained (`max-w-2xl`).

Then three stacked rows, one per entry in the `FEATURES` array:

| id | Title | Icon | Accent | Proof label |
|---|---|---|---|---|
| `runtime` | Zero-runtime overhead | `Activity` | emerald | Build Output |
| `types` | Strictly typed APIs | `ShieldCheck` | amber | Editor Diagnostics |
| `headless` | Headless accessibility | `Cpu` | rose | DOM Inspector |

Each row is split into two panels:
- **Claim panel** (flex-1): icon chip + title inline, then description paragraph below.
- **Proof panel** (fixed `md:w-80`, separated by a left border on desktop / top border on mobile): a small "terminal" with its own header bar (label + two decorative dots) and a body that shows 3–4 lines of monospace "output" text.

### 4.3 Interaction Design

**Skeleton → reveal on hover (proof panel):**
- Default state: proof body shows 3 gray skeleton/placeholder bars (`bg-zinc-800/50`, varying widths) at full opacity — implying "loading" or "redacted" content.
- On hover (`group-hover`): skeleton bars fade out (`opacity-100 → opacity-0`) while the real proof text fades/slides in (`opacity-0 translate-y-2 → opacity-100 translate-y-0`), both via `transition-all duration-300`. This is pure CSS group-hover, not JS state.
- Proof text lines use per-feature accent colors, with "dim" lines (marked `dim: true` in data) rendered in muted zinc `#71717a` and emphasized lines in the feature's accent hex (emerald `#34d399`, amber `#fbbf24`, or rose `#fb7185`) — colors are set inline via `style`, driven by a lookup on `feature.accent`.

**Scanning light-sweep (proof panel, hover only):**
- On row hover (`hoveredId === feature.id`, tracked in React state separately from the CSS-only skeleton reveal), an `AnimatePresence`-wrapped `motion.div` animates a horizontal band from `top: 0%` to `top: 100%` with an opacity pulse (`[0, 0.5, 0]`), looping infinitely (`repeat: Infinity`, 1.5s, linear) while hovered — mimicking a scanner/CRT sweep across the proof panel. Color is derived from the feature's accent (`to-{color}-500/10` gradient), though note this is a **template-literal Tailwind class** (`bg-gradient-to-b from-transparent to-${feature.accent.split('-')[1]}-500/10`) which **will not work with Tailwind's JIT compiler** since dynamically constructed class names aren't statically analyzable — see Section 6.

**Row-level hover:**
- Border brightens (`border-zinc-800/80 → border-zinc-700`), background lifts one step (`#111115 → #15151a`), and a colored ambient shadow appears, unique per feature — all via Tailwind `hover:` and the precomputed `glow` string per feature object.

### 4.4 Responsive Behavior
- Rows are `flex-col` (claim stacked above proof) below `md`, `flex-row` (side-by-side) at `md` and above.
- Proof panel border shifts from `border-t` (mobile) to `border-l` (desktop) accordingly.

---

## 5. Data Model Reference

```ts
DEMO_CODE: Array<{
  num: number;
  type: 'comment' | 'code' | 'empty';
  text?: string;
  indent?: boolean;
  tokens?: Array<{ text: string; className: string }>;
}>

EXPLANATIONS: Record<number, string>  // keyed by DEMO_CODE line number

FEATURES: Array<{
  id: string;
  title: string;
  description: string;
  icon: LucideIcon;
  accent: string;       // Tailwind text-color class
  glow: string;         // Tailwind hover:shadow class, pre-built per feature
  proof: {
    label: string;
    lines: Array<{ text: string; dim: boolean }>;
  };
}>
```

All content is hardcoded in the file — there are no external props on `Component`; it renders with zero configuration. To make it reusable, `DEMO_CODE`, `EXPLANATIONS`, and `FEATURES` would need to be lifted to props.

---

## 6. Implementation Notes & Known Issues

1. **Dynamic Tailwind class bug:** `` `to-${feature.accent.split('-')[1]}-500/10` `` builds a class name at runtime. Tailwind only includes classes it can find as complete strings at build time, so this gradient will likely render as transparent/no-op in production unless the three full class names (`to-emerald-500/10`, `to-amber-500/10`, `to-rose-500/10`) are added to a safelist or written out explicitly with a conditional.
2. **Copy button doesn't copy:** wire up `navigator.clipboard.writeText()` with the actual demo source string.
3. **No props/config:** component is fully self-contained; treat this as a page section template to duplicate/edit rather than a reusable primitive as shipped.
4. **Accessibility gaps to address before shipping:**
   - Walkthrough buttons rely on `onMouseEnter`/`onMouseLeave` only — no keyboard/focus equivalent, so the line-highlight interaction is inaccessible via keyboard or to screen reader users.
   - Decorative icons (`Terminal`, `FileCode2`, feature icons) have no `aria-hidden`.
   - Color is the primary signal for "active" state (rose highlight) — should be paired with a non-color indicator for contrast-sensitive users.
5. **Required npm dependencies:** `framer-motion`, `lucide-react` (Tailwind CSS and TypeScript assumed already present in a shadcn-style project).
6. **Two full-viewport (`min-h-screen`) sections back to back** means this component alone is a ~2-screen scroll experience; if embedding within a longer page, consider whether `min-h-screen` should be reduced.

---

## 7. Suggested Use Cases

- Hero + first feature section for a developer tool, component library, CLI, or SDK landing page.
- Best suited for products that can show a literal "before you write code" moment (config-free setup, instant preview, type safety) — the whole page leans on "show, don't tell" via faux terminal/editor UI.
