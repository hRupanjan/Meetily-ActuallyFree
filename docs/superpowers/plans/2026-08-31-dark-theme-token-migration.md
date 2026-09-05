# Dark Theme Token Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `.dark .*` `!important` override shim with a semantic-token color system so components consume intent-named tokens and `.dark` flips only `--af-*` variable values (colors, never structure).

**Architecture:** One palette (`--af-*`) is the single source of truth. `tailwind.config.js` maps clear semantic color names (`surface*`, `content*`, `brand*`, …) directly to `--af-*` hex vars, and realigns shadcn's tokens (`card`/`muted`/`border`/…) to the same vars. Components migrate surface-by-surface from raw utilities (`bg-white`, `text-gray-600`, …) to semantic tokens. The shim stays live during migration (semantic classes have different names, so no double-paint) and is deleted whole in the final teardown once no raw utilities remain.

**Tech Stack:** Next.js 14, Tailwind CSS 3.4 (class dark mode), shadcn/ui, CSS custom properties.

**Spec:** [docs/superpowers/specs/2026-08-31-dark-theme-token-migration-design.md](../specs/2026-08-31-dark-theme-token-migration-design.md)

## Global Constraints

- Single Tailwind config is `tailwind.config.ts` (the old `tailwind.config.js` and duplicate `postcss.config.mjs` were deleted during prep). Edit the `.ts`.
- The app is browser-debuggable at http://localhost:3118 via `src/lib/tauriBrowserShim.ts` (no-op Tauri bridge when not in Tauri). CSS-lint noise silenced by `.vscode/settings.json`.
- NEVER run `next build` while the dev server is running — it clobbers the shared `.next` and 500s the dev server (`Cannot find module './NNN.js'`). To validate, stop dev first, or rely on the dev server's own compile.
- Preserve BOTH light and dark appearance. This changes the mechanism, not the design.
- No unit-test framework exists for CSS. Verification per task = (a) `npx tsc --noEmit` clean, (b) grep gate on migrated scope = 0, (c) manual visual check in BOTH themes (`pnpm run tauri:dev:cpu`, toggle theme in Settings), (d) run the dev server warm before eyeballing (first-render chunk race is normal — Ctrl+R).
- Keep shadcn `primary`, `destructive`, `chart-*` semantics unchanged.
- Do NOT touch these `!important` rules (not theme color): BlockNote layout (globals.css 185-212), minibar transparency (470-476).
- Commit after each task. Conventional commit messages.

---

## Mapping Reference (canonical — every migration task applies this)

Replace raw utility → semantic token. Applies to base, `hover:`, `focus:`, `dark:`, `sm:` etc. variants (replace the color part, keep the variant prefix). When a `dark:` variant exists on a migrated element, DELETE it — the token already themes itself.

| Raw utility(s) | Replace with |
|---|---|
| `bg-white` | `bg-surface` |
| `bg-gray-50`, `bg-slate-50`, `bg-neutral-50`, `bg-gray-100` | `bg-surface-2` |
| `bg-gray-200`, `bg-gray-300` | `bg-surface-hover` |
| `hover:bg-gray-50/100/200/300` | `hover:bg-surface-hover` |
| `text-black`, `text-gray-900`, `text-gray-800`, `text-gray-700` | `text-content` |
| `text-gray-600`, `text-gray-500` | `text-content-muted` |
| `text-gray-400`, `text-gray-300` | `text-content-subtle` |
| `border-gray-100/200/300` | `border-border` |
| bare `border` (color only; keep width) | add `border-border` |
| `border-t/b/l/r` needing color | keep + ensure `border-border` |
| `bg-blue-600` | `bg-brand` |
| `hover:bg-blue-700` | `hover:bg-brand-hover` |
| `text-blue-600`, `text-blue-500` | `text-brand` |
| `text-blue-800` | `text-brand` |
| `bg-blue-50`, `bg-blue-100`, `bg-blue-200` | `bg-brand-soft` |
| `hover:bg-blue-100/200` | `hover:bg-surface-hover` |
| `bg-green-50` | `bg-success-soft` |
| `text-green-800`, `text-green-700` | `text-success` |
| `from-*-50 … to-*-50` gradient pills | drop gradient classes, use `bg-surface-2` (per-case) |
| `shadow-sm/md/lg` | leave unchanged (values live in config) |

Judgment cases (do NOT blindly replace):
- A literal white/black that must stay literal regardless of theme (e.g. text on a fixed-color brand button, an overlay scrim `bg-black/50`) — leave as-is. Only migrate colors that the shim was theming. Cross-check: if the shim (globals.css 275-358, 487-498) has a rule for that utility, migrate it; if not, leave it.
- `text-white` on a colored button (e.g. inside `bg-brand`) stays `text-white` — the shim never retargeted `text-white`.

---

### Task 1: Foundation — tokens, vars, theme-agnostic structure

Adds the semantic vocabulary and new vars, realigns shadcn tokens to `--af-*`, and moves radius/shadow into config so they stop being theme-flipped. No component changes yet; the shim stays active, so both themes still render correctly.

**Files:**
- Modify: `frontend/tailwind.config.ts`
- Modify: `frontend/src/app/globals.css` (`:root` + `html.dark` af-var blocks, ~220-271)

**Interfaces:**
- Produces (Tailwind color tokens, usable as `bg-`/`text-`/`border-`): `surface`, `surface-2`, `surface-hover`, `surface-active`, `content`, `content-muted`, `content-subtle`, `border-strong`, `brand`, `brand-hover`, `brand-soft`, `success`, `success-soft`. Plus realigned shadcn tokens resolving to af vars.
- Produces (CSS vars, light/dark): `--af-success`, `--af-success-soft`, `--af-accent-hover`.

- [ ] **Step 1: Add new af vars**

In `globals.css` `:root` (after `--af-accent-soft`, ~line 235) add:

```css
  --af-accent-hover: #1d4ed8;
  --af-success: #15803d;
  --af-success-soft: #ecfdf3;
```

In `html.dark` (after `--af-accent-soft`, ~line 264) add:

```css
  --af-accent-hover: #3b7ae8;
  --af-success: #7ee2a8;
  --af-success-soft: #12251a;
```

- [ ] **Step 2: Add semantic + realign colors in `tailwind.config.ts`**

In `theme.extend.colors`, add the custom tokens and realign shadcn ones to af vars. Replace the existing `colors` block's affected entries so it reads:

```js
colors: {
  background: 'var(--af-bg)',
  foreground: 'var(--af-text)',
  border: 'var(--af-border)',
  input: 'var(--af-border)',
  ring: 'var(--af-accent)',
  primary: { DEFAULT: 'hsl(var(--primary))', foreground: 'hsl(var(--primary-foreground))' },
  secondary: { DEFAULT: 'var(--af-panel-2)', foreground: 'var(--af-text)' },
  tertiary: 'var(--af-text-3)',
  card: { DEFAULT: 'var(--af-panel)', foreground: 'var(--af-text)' },
  popover: { DEFAULT: 'var(--af-panel)', foreground: 'var(--af-text)' },
  muted: { DEFAULT: 'var(--af-panel-2)', foreground: 'var(--af-text-2)' },
  accent: { DEFAULT: 'var(--af-hover)', foreground: 'var(--af-text)' },
  destructive: { DEFAULT: 'hsl(var(--destructive))', foreground: 'hsl(var(--destructive-foreground))' },
  chart: { '1': 'hsl(var(--chart-1))', '2': 'hsl(var(--chart-2))', '3': 'hsl(var(--chart-3))', '4': 'hsl(var(--chart-4))', '5': 'hsl(var(--chart-5))' },
  // semantic app tokens
  surface: 'var(--af-panel)',
  'surface-2': 'var(--af-panel-2)',
  'surface-hover': 'var(--af-hover)',
  'surface-active': 'var(--af-active)',
  content: 'var(--af-text)',
  'content-muted': 'var(--af-text-2)',
  'content-subtle': 'var(--af-text-3)',
  'border-strong': 'var(--af-border-strong)',
  brand: 'var(--af-accent)',
  'brand-hover': 'var(--af-accent-hover)',
  'brand-soft': 'var(--af-accent-soft)',
  success: 'var(--af-success)',
  'success-soft': 'var(--af-success-soft)',
},
```

- [ ] **Step 3: Make radius + shadow theme-agnostic in config**

In `theme.extend`, add `boxShadow` and repoint `borderRadius` to af vars:

```js
borderRadius: {
  lg: 'var(--af-radius)',
  md: 'var(--af-radius-sm)',
  sm: 'var(--af-radius-sm)',
},
boxShadow: {
  sm: 'var(--af-shadow-sm)',
  DEFAULT: 'var(--af-shadow-md)',
  md: 'var(--af-shadow-md)',
  lg: 'var(--af-shadow-lg)',
  xl: 'var(--af-shadow-lg)',
  '2xl': 'var(--af-shadow-lg)',
},
```

- [ ] **Step 4: Typecheck + build**

Run: `cd frontend && npx tsc --noEmit && node node_modules/next/dist/bin/next build`
Expected: compiles clean (config changes don't affect TS; build validates Tailwind).

- [ ] **Step 5: Visual smoke — both themes**

With `pnpm run tauri:dev:cpu`, open the app, toggle light/dark in Settings. Expected: app looks the same as before (shim still handles raw utilities; realigned shadcn tokens may make `ui/*` dark surfaces navy instead of gray — that is intended and should look cohesive).

- [ ] **Step 6: Commit**

```bash
git add frontend/tailwind.config.js frontend/src/app/globals.css
git commit -m "feat(theme): add semantic tokens backed by af palette; realign shadcn vars; theme-agnostic radius/shadow"
```

---

### Task 2: Remove dark structural overrides + fix button group

Deletes the `.dark` rules that change shape/motion so dark only recolors, and reverts the button-group workaround now that the dark radius rule is gone.

**Files:**
- Modify: `frontend/src/app/globals.css:375-400` (letter-spacing, radius, transitions)
- Modify: `frontend/src/components/MeetingDetails/TranscriptButtonGroup.tsx:109`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing new; removes rules.

- [ ] **Step 1: Delete structural dark rules**

In `globals.css`, delete these three blocks (comments + rules):
- `.dark h1, .dark h2, .dark h3, .dark .text-2xl…{ letter-spacing: -0.018em; }` (~375-378)
- `.dark .rounded-lg { … }` and `.dark .rounded-md { … }` (~382-383)
- `.dark button, .dark a, … { transition: … }` (~387-400)

- [ ] **Step 2: Revert button-group hack to plain classes**

In `TranscriptButtonGroup.tsx`, change the `ButtonGroup` className to:

```tsx
      <ButtonGroup className="shrink-0 [&>button]:shadow-none [&>button:not(:first-child)]:rounded-l-none [&>button:not(:first-child)]:border-l-0 [&>button:not(:last-child)]:rounded-r-none">
```

(Drops the `!` prefixes — no `!important` radius rule left to fight.)

- [ ] **Step 3: Typecheck**

Run: `cd frontend && npx tsc --noEmit`
Expected: clean.

- [ ] **Step 4: Visual — both themes**

Verify: (a) transcript toolbar renders as ONE joined pill in both themes; (b) corner radii, heading spacing, and motion look identical between light and dark (dark no longer "reshapes"). Warm the dev server, Ctrl+R if first render errors.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/globals.css frontend/src/components/MeetingDetails/TranscriptButtonGroup.tsx
git commit -m "feat(theme): stop dark from changing radius/tracking/motion; join transcript button group"
```

---

## Migration tasks (3–9)

Each task migrates one surface using the **Mapping Reference**. The shim is NOT touched here. For every task, the recipe and gates are identical (repeated here so tasks can be executed out of order):

**Recipe per file:** for each raw utility present, apply the Mapping Reference; delete any now-redundant `dark:` color variant on the same element; leave judgment-case literals. Do not change layout, spacing, or non-color classes.

**Gates per task:**
- `cd frontend && npx tsc --noEmit` → clean.
- Grep gate (scope = this task's paths):
  `grep -rnE 'bg-white|bg-gray-|text-gray-|text-black|border-gray-|bg-blue-|text-blue-|bg-green-|text-green-|from-(blue|purple|red|orange|green)-50' <paths>` → only judgment-case literals remain (each justified in the commit body); no shim-mapped utility remains.
- Visual, BOTH themes, of the actual screens these files render.
- Commit.

---

### Task 3: App shell + pages

**Files:** `app/page.tsx`, `app/_components/SettingsModal.tsx`, `app/_components/StatusOverlays.tsx`, `app/_components/TranscriptPanel.tsx`, `app/meeting-details/page.tsx`, `app/notes/[id]/page.tsx`, `app/person/page.tsx`, `app/settings/page.tsx`, `app/minibar/page.tsx`, `components/Sidebar/index.tsx`

**Interfaces:** Consumes Task 1 tokens. Produces migrated shell.

- [ ] **Step 1:** Apply the per-file Recipe to each file above.
- [ ] **Step 2:** Run typecheck + grep gate (paths: `src/app src/components/Sidebar`).
- [ ] **Step 3:** Visual both themes — home list, sidebar, meeting-details shell, settings page, minibar.
- [ ] **Step 4:** Commit `refactor(theme): migrate app shell + pages to semantic tokens`.

### Task 4: Meeting details + AI summary

**Files:** all of `components/MeetingDetails/*` (InsightTabs, PostCallProcessingDialog, RetranscribeDialog, SpeakerRenameDialog, SummaryGeneratorButtonGroup, SummaryPanel, SummaryRegenerationDialog, SummaryUpdaterButtonGroup, TemplateEditorModal, TranscriptButtonGroup), `components/AISummary/*` (Block, Section, index), `components/VirtualizedTranscriptView.tsx`, `components/EditableTitle.tsx`, `components/EmptyStateSummary.tsx`, `components/ConfidenceIndicator.tsx`

**Interfaces:** Consumes Task 1 tokens.

- [ ] **Step 1:** Apply Recipe per file.
- [ ] **Step 2:** Typecheck + grep gate (path: `src/components/MeetingDetails src/components/AISummary`, plus the four singletons).
- [ ] **Step 3:** Visual both themes — transcript, AI summary, action items, key topics, all summary dialogs.
- [ ] **Step 4:** Commit `refactor(theme): migrate meeting-details + AI summary to semantic tokens`.

### Task 5: Settings + model managers

**Files:** `components/*Settings*.tsx` (Recording, Preference, Beta, Diarization, Transcript, SummaryLanguage, SummaryModel, MeetingDetection, AnalyticsConsentSwitch), `components/About.tsx`, `components/AboutSettings.tsx`, `components/Info.tsx`, `components/ModelSettingsModal.tsx`, `components/BuiltInModelManager.tsx`, `components/WhisperModelManager.tsx`, `components/ParakeetModelManager.tsx`, `components/ModelDownloadProgress.tsx`, `components/LanguageSelection.tsx`, `components/LanguagePickerPopover.tsx`, `components/SummaryLanguageSettings.tsx`, `components/molecules/form-components/form-input-item.tsx`

**Interfaces:** Consumes Task 1 tokens.

- [ ] **Step 1:** Apply Recipe per file.
- [ ] **Step 2:** Typecheck + grep gate on those files.
- [ ] **Step 3:** Visual both themes — every Settings tab, model download UI.
- [ ] **Step 4:** Commit `refactor(theme): migrate settings + model managers to semantic tokens`.

### Task 6: Onboarding

**Files:** `components/onboarding/OnboardingContainer.tsx`, `components/onboarding/shared/*` (PermissionRow, ProgressIndicator, StatusIndicator), `components/onboarding/steps/*` (AudioTestStep, DownloadProgressStep, SetupOverviewStep, WelcomeStep, YourNameStep)

**Interfaces:** Consumes Task 1 tokens.

- [ ] **Step 1:** Apply Recipe per file.
- [ ] **Step 2:** Typecheck + grep gate (path: `src/components/onboarding`).
- [ ] **Step 3:** Visual both themes — full onboarding flow.
- [ ] **Step 4:** Commit `refactor(theme): migrate onboarding to semantic tokens`.

### Task 7: Recording + audio + live

**Files:** `components/RecordingControls.tsx`, `components/RecordingStatusBar.tsx`, `components/RecordingSettings.tsx` (if not done in T5), `components/AudioBackendSelector.tsx`, `components/AudioLevelMeter.tsx`, `components/DeviceSelection.tsx`, `components/LiveAudioVisualizer.tsx`, `components/LiveAssistant/LiveAssistant.tsx`, `components/ChunkProgressDisplay.tsx`, `components/shared/DownloadProgressToast.tsx`

**Interfaces:** Consumes Task 1 tokens.

- [ ] **Step 1:** Apply Recipe per file.
- [ ] **Step 2:** Typecheck + grep gate on those files.
- [ ] **Step 3:** Visual both themes — start/stop recording, live bar, device pickers.
- [ ] **Step 4:** Commit `refactor(theme): migrate recording + audio UI to semantic tokens`.

### Task 8: Dialogs, notifications, misc

**Files:** `components/ConfirmationModel/confirmation-modal.tsx`, `components/CrashReportDialog.tsx`, `components/AnalyticsDataModal.tsx`, `components/GlobalSearchDialog.tsx`, `components/ImportAudio/*` (ImportAudioDialog, ImportDropOverlay), `components/DatabaseImport/*` (HomebrewDatabaseDetector, LegacyDatabaseImport), `components/TranscriptRecovery/TranscriptRecovery.tsx`, `components/UpdateNotification.tsx`, `components/MessageToast.tsx`, `components/ComplianceNotification.tsx`, `components/PermissionWarning.tsx`, `components/LocalStackStatus.tsx`, `components/Logo.tsx`

**Interfaces:** Consumes Task 1 tokens.

- [ ] **Step 1:** Apply Recipe per file.
- [ ] **Step 2:** Typecheck + grep gate on those files.
- [ ] **Step 3:** Visual both themes — global search, import flows, update/crash dialogs, toasts.
- [ ] **Step 4:** Commit `refactor(theme): migrate dialogs + notifications to semantic tokens`.

### Task 9: shadcn ui primitives

Careful task — these are library components. Most already use semantic tokens; migrate only the raw utilities present, and verify no `ui/*` visual change.

**Files:** `components/ui/button.tsx`, `components/ui/dialog.tsx`, `components/ui/dropdown-menu.tsx`, `components/ui/input.tsx`, `components/ui/popover.tsx`, `components/ui/select.tsx`, `components/ui/sheet.tsx`, `components/ui/switch.tsx`, `components/ui/textarea.tsx`

**Interfaces:** Consumes Task 1 tokens.

- [ ] **Step 1:** Apply Recipe per file. Prefer existing shadcn tokens where already present (`bg-background`, `text-muted-foreground`) — only touch raw `bg-gray-*`/`bg-white`/etc.
- [ ] **Step 2:** Typecheck + grep gate (path: `src/components/ui`).
- [ ] **Step 3:** Visual both themes — dropdowns, dialogs, selects, switches, inputs across the app.
- [ ] **Step 4:** Commit `refactor(theme): migrate ui primitives to semantic tokens`.

---

### Task 10: Teardown — delete the shim

Once Tasks 3–9 are done, no shim-mapped raw utility remains. Delete the shim and dead config, and make the last dark-only cosmetic rules theme-agnostic.

**Files:**
- Modify: `frontend/src/app/globals.css` (delete color shim: ~275-358, 487-498; convert focus/scroll/selection)
- Modify: `frontend/src/app/globals.css` `:root`/`.dark` shadcn HSL var blocks (remove now-unused vars)

(Config is already single `tailwind.config.ts` — no config deletion here.)

**Interfaces:** Consumes all prior tasks.

- [ ] **Step 1: Prove zero raw utilities app-wide**

Run:
```bash
cd frontend/src && grep -rnE 'bg-white|bg-gray-|text-gray-|text-black|border-gray-|bg-blue-|text-blue-|bg-green-|text-green-|from-(blue|purple|red|orange|green)-50' --include=*.tsx --include=*.ts .
```
Expected: only documented judgment-case literals (e.g. `bg-black/50` scrims, `text-white` on brand buttons). If a shim-mapped utility remains, STOP and migrate it before deleting its shim rule.

- [ ] **Step 2: Delete the color shim**

In `globals.css` delete the `.dark` color-remap blocks: backgrounds/text/borders (275-287), input blocks (289-294) — but KEEP the `.af-bare` (299-303) and `[data-slot=input-group]` (310-318) rules only if the Ask-AI bar / search InputGroup still rely on them; otherwise fold their `bg-transparent`/`border-0` into those components and delete. Delete blue/gray/prose (320-327), shadow shim (331-333), gradient flatten (337-354), green (357-358), divider (485-488), accent surfaces + primary (492-498).

- [ ] **Step 3: Make focus/scroll/selection theme-agnostic**

Convert `.dark :focus-visible` (402-408), `.dark input:focus…` (409-412), `.dark [cmdk-input-wrapper]…` (416-420), `.dark *` scrollbars (447-460), `.dark ::selection` (479-482): drop the `.dark` prefix so they apply in both themes (they already use `--af-*` vars, which flip per theme). Keep the `[cmdk-input-wrapper]` and minibar rules' `!important` (they fight library CSS).

- [ ] **Step 4: Remove unused shadcn HSL vars**

In `globals.css` `:root` and `.dark` (80-133), delete the vars no longer referenced by the config (`--background`, `--foreground`, `--card*`, `--popover*`, `--secondary*`, `--muted*`, `--accent*`, `--border`, `--input`, `--ring`). KEEP `--primary*`, `--destructive*`, `--chart-*`, `--radius` (still referenced).

- [ ] **Step 5: (config already consolidated during prep — skip)**

- [ ] **Step 6: Grep gate — no dark color rules**

Run: `grep -nE '\.dark .*(background|color|border-color)' frontend/src/app/globals.css`
Expected: no color-remap rules remain (only theme-agnostic cosmetics converted in Step 3, and any intentionally-kept library-fighting rules).

- [ ] **Step 7: Typecheck + build**

Run: `cd frontend && npx tsc --noEmit && node node_modules/next/dist/bin/next build`
Expected: clean.

- [ ] **Step 8: Full visual regression — both themes**

Walk every surface (Tasks 3–9 checklist) in light and dark. Confirm nothing shifted vs. pre-teardown.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(theme): delete dark override shim and dead config; theme-agnostic focus/scroll/selection"
```

---

## Self-Review

**Spec coverage:** Foundation (T1) ✓; structural removal (T2) ✓; per-surface migration covering all 90 files (T3–T9) ✓; teardown/shim delete/dead-config/focus-scroll/unused-vars (T10) ✓; mapping table ✓; edge cases — input escape hatches (T10 S2), focus ring (T10 S3), gradients (Mapping Reference) ✓; grep gates + both-theme visual per task ✓.

**Placeholder scan:** No TBD/TODO. "Recipe"/"Gates" are defined once and applied — that is DRY data reuse, not a "similar to Task N" code omission. Judgment-case literals are explicitly defined in the Mapping Reference.

**Type consistency:** Token names are identical across Task 1 (definition) and the Mapping Reference (usage): `surface`, `surface-2`, `surface-hover`, `surface-active`, `content`, `content-muted`, `content-subtle`, `border-strong`, `brand`, `brand-hover`, `brand-soft`, `success`, `success-soft`. Var names consistent: `--af-accent-hover`, `--af-success`, `--af-success-soft`.

**Known open item for executor:** exact file→utility incidence is discovered by grep at execution time (the counts in the spec are aggregates); the Recipe + grep gate make each task self-verifying regardless.
