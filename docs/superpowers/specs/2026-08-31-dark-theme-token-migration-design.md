# Dark Theme Token Migration — Design

Date: 2026-08-31
Status: Approved design (pre-plan)

## Problem

Dark mode is implemented as a `.dark .*` override shim in
[globals.css](../../../frontend/src/app/globals.css) that retargets raw Tailwind
color utilities (`bg-white`, `text-gray-900`, `bg-blue-600`, …) to `--af-*`
variables using `!important`. Consequences the user wants fixed:

1. The `!important` wall is restrictive — components cannot vary a themed color
   without fighting it (this broke the transcript button-group radius).
2. Dark is driven by *per-utility override rules*, not purely by variables.
3. Dark also changes **structure** (radius, letter-spacing, forced transitions),
   so it "changes styling completely" instead of only recoloring.

## Goal

Components consume **semantic color tokens**; `.dark` flips only `--af-*`
variable *values* (colors), never structure. Delete the shim entirely. One
palette (`--af-*`) as the single source of truth.

## Current state (facts)

- **Two Tailwind configs.** `tailwind.config.js` (rich shadcn tokens) is
  ACTIVE; `tailwind.config.ts` (minimal) is dead (v3 resolves `.js` before
  `.ts`). Delete the `.ts`.
- **Two palettes.** shadcn HSL vars (`--background`, `--card`, `--muted`,
  `--border`… lines 80-133) are plain gray in dark. The `--af-*` palette
  (lines 220-271) is the tuned navy skin with more levels. shadcn `ui/*`
  components use `bg-card`/`text-foreground` and therefore currently render
  gray-dark, slightly inconsistent with the navy app surfaces.
- **Scale.** ~77 files, ~1000+ raw color-utility occurrences.
- **The shim is the mapping spec** — it already encodes raw-utility → af-var.

## Target token vocabulary (clear custom names)

Backed directly by `--af-*` hex vars in `tailwind.config.js` `theme.extend.colors`:

| Token | af var | Meaning |
|---|---|---|
| `surface` | `--af-panel` | level-1 surface (cards, sidebar) |
| `surface-2` | `--af-panel-2` | level-2 raised/nested/input |
| `surface-hover` | `--af-hover` | interactive hover bg |
| `surface-active` | `--af-active` | pressed/selected bg |
| `content` | `--af-text` | primary text |
| `content-muted` | `--af-text-2` | secondary text |
| `content-subtle` | `--af-text-3` | tertiary text |
| `border` (realign) | `--af-border` | hairline |
| `border-strong` | `--af-border-strong` | emphasized divider |
| `brand` | `--af-accent` | brand blue (actions, links) |
| `brand-soft` | `--af-accent-soft` | tinted info/selected surface |
| `success` | `--af-success` (new) | green text |
| `success-soft` | `--af-success-soft` (new) | green banner bg |

Also **realign shadcn semantic vars to af** so `ui/*` components join the same
palette (in `tailwind.config.js`, point these at af vars directly):

- `background`→`--af-bg`, `foreground`→`--af-text`
- `card`/`popover`→`--af-panel` (+ `-foreground`→`--af-text`)
- `muted`→`--af-panel-2`, `muted-foreground`→`--af-text-2`
- `secondary`→`--af-panel-2` (+ `-foreground`→`--af-text`)
- `accent` (shadcn = hover surface)→`--af-hover` (+ `-foreground`→`--af-text`)
- `border`→`--af-border`, `input`→`--af-border`, `ring`→`--af-accent`
- **Keep** shadcn `primary`, `destructive`, `chart-*` unchanged (avoids
  changing `ui/Button` default variant behavior). Remove the now-unused shadcn
  HSL vars that were replaced; keep the ones still referenced.

New af vars to add (light / dark):
- `--af-success`: `#15803d` / `#7ee2a8`
- `--af-success-soft`: `#ecfdf3` (approx green-50) / `#12251a`
- `--af-accent-hover`: `#1d4ed8` (blue-700) / `#3b7ae8` — used by `hover:bg-brand`
  (shim used `#3b7ae8` in dark); expose as token `brand-hover`.

**Structure becomes theme-agnostic** (defined once, not flipped by `.dark`):
- `borderRadius`: `lg`→`--af-radius`, `md`/`sm`→`--af-radius-sm` (or a ramp),
  defined in `:root` only.
- `boxShadow`: `sm`/`md`/`lg`→`--af-shadow-sm/md/lg` (af-shadow already has
  light and dark values, so `shadow-sm` etc. work in both themes).

## Full raw → semantic mapping

| Raw utility(s) | Replace with |
|---|---|
| `bg-white` | `bg-surface` |
| `bg-gray-50`, `bg-slate-50`, `bg-neutral-50`, `bg-gray-100` | `bg-surface-2` |
| `bg-gray-200`, `bg-gray-300` | `bg-surface-hover` |
| `hover:bg-gray-50/100/200/300` | `hover:bg-surface-hover` |
| `text-black`, `text-gray-900/800/700` | `text-content` |
| `text-gray-600/500` | `text-content-muted` |
| `text-gray-400/300` | `text-content-subtle` |
| `border`, `border-gray-100/200/300`, `border-t/b/l/r` | `border-border` / keep + `border-border` |
| `bg-blue-600`, `hover:bg-blue-700` | `bg-brand`, `hover:bg-brand` (hover: darker via af) |
| `text-blue-600/500`, `text-blue-800` | `text-brand` |
| `bg-blue-50/100/200`, `hover:bg-blue-*` | `bg-brand-soft` / `hover:bg-surface-hover` |
| `bg-green-50` | `bg-success-soft` |
| `text-green-800/700` | `text-success` |
| `from-*-50 … to-*-50` gradient pills (~5 files) | per-case → `bg-surface-2` (drop gradient) |
| `shadow-sm/md/lg` | unchanged (values move to config) |

Edge cases:
- **Input transparency escape hatches** (`.af-bare`, `[data-slot=input-group]`
  inner input — globals 299-318): the blanket `.dark input {…}` rule is being
  deleted, so these become normal component styling. Verify the Ask-AI bar
  input and the search InputGroup explicitly set `bg-transparent`/`border-0`
  after migration; drop the now-redundant `.dark` overrides.
- **Focus ring** (`.dark :focus-visible` 402-420): move to a theme-agnostic
  base rule using `--af-accent` so light gets the same ring; delete the
  `.dark`-scoped version. (Honors "dark shouldn't have its own rules".)
- **Scrollbars / selection** (`.dark *`, `.dark ::selection`): convert to
  theme-agnostic using vars, or leave (cosmetic). Low priority; a late phase.
- **Minibar transparency** (470-476) and **BlockNote layout** (185-212):
  unrelated to theme — keep as-is, `!important` retained.

## Execution — staged per surface

Semantic class names differ from raw utilities, so the shim and migrated code
coexist with no double-paint. Delete each shim rule only once its raw utility
is fully gone (grep = 0).

- **Phase 0 — Foundation:** add tokens + af vars + realign shadcn vars +
  radius/shadow config; make structure theme-agnostic. No component change yet;
  both themes still correct (shim still active for raw utilities).
- **Phase 1 — Remove structural dark rules:** delete `.dark` radius,
  letter-spacing, forced transitions (375-400). Revert button-group `!` hack to
  plain `rounded-l-none/border-l-0/rounded-r-none`.
- **Phases 2-n — Migrate by surface**, each a reviewable chunk with a
  both-theme visual check, deleting the corresponding shim rules as utilities
  hit zero:
  - Sidebar (`components/Sidebar/*`)
  - Meeting details (`components/MeetingDetails/*`, `app/meeting-details/*`)
  - AI summary / insights (`components/AISummary/*`, `InsightTabs`)
  - Settings + modals (`components/*Settings*`, `_components/SettingsModal`)
  - Onboarding (`components/onboarding/**`)
  - Recording controls / status bars
  - Remaining `app/**` pages + misc components
- **Final phase — Teardown:** delete remaining shim, delete dead
  `tailwind.config.ts`, remove unused shadcn HSL vars, convert focus/scroll/
  selection to theme-agnostic. Grep proves zero raw color utilities + zero
  `.dark .*` color rules remain.

## Testing

- Per phase: launch app (`pnpm run tauri:dev:cpu`), eyeball the migrated
  surface in **both** light and dark; compare against pre-migration.
- Grep gates: after each phase, `grep` the migrated utilities → 0 in that
  surface. Final: 0 app-wide.
- No automated visual tests exist; verification is manual per surface (called
  out because it gates each phase).

## Risks

- **Visual regression** on ~77 files — mitigated by staging + per-surface
  both-theme check, not one big sweep.
- **Ambiguous replacements** (a literal blue that should stay vs a brand blue) —
  mitigated by reviewing each surface's diff, not blind scripted replace.
- **shadcn realignment** shifts `ui/*` dark surfaces from gray to navy — this is
  intended (consistency) but must be eyeballed (dialogs, dropdowns, popovers,
  command palette).

## Out of scope

- Component structural refactors beyond color/token usage.
- Changing shadcn `primary`/`destructive`/`chart` semantics.
- Light-theme redesign — appearance is preserved, only the mechanism changes.
