---
name: refactor-page-ui
description: Light UI pass on one Vue page. Swap to Tf* components, tidy spacing, add skeleton loading. Does NOT restyle fonts, sizes, row tints, or layout. Only recolors what breaks dark mode (see Step 4b). Use when the user names a page/file and says refactor UI, apply components, or /refactor-page-ui.
---

# Refactor page UI (light pass)

Input: ONE `.vue` file (plus its direct child list/card component if the page only wraps it). Do not read other pages.

## Scope — ONLY these three things

1. **Components**: replace old controls with the shared `Tf*` ones.
2. **Spacing**: adjust padding/gaps only.
3. **Skeleton / loading**: replace spinners/blank loading with skeletons.

Anything else = leave it alone.

## Hard rules (never break)

- Do NOT remove or change: row tints, side accent bars, status colors, hex colors, Quasar color classes, font sizes, font weights, border radius, shadows, icons, text, layout, columns, or CSS that is not about spacing.
- Do NOT delete existing per-status style functions or CSS. Keep how the page looks.
- Do NOT change behavior: props, emits, queries, routes, handlers, i18n keys.
- Do NOT split files, rename things, or "clean up" unrelated code.
- If a Tf* component would change the look noticeably (size, color, shape), skip it and list it in the final line.

## Step 1 — Measure (one call)

`wc -l <file>` and
`rg -n "<q-btn|<q-btn-toggle|<q-tabs|position=\"right\"|<q-spinner|q-skeleton|isLoading|q-pa-(lg|xl)" <file>`

## Step 2 — Component swaps (allowed)

| Found | Replace with |
|---|---|
| `q-btn` (text/primary/secondary/danger actions) | `TfBtn` (variant: primary/secondary/tertiary/danger/link). Keep label, icon, handlers, loading, disable. |
| Icon-only `q-btn flat round dense` | `TfBtn variant="icon"` (+ keep `q-tooltip`) |
| `q-tabs` / hand-rolled filter pills / `quick-filter-toggle` | `TfDrawerSectionTabs` (list filters) or `TfDrawerSectionTabsHeader` (drawer + close) |
| `q-btn-toggle` (filters) | `TfDrawerSectionTabs` when it is a section chooser; else skip if layout differs |
| `q-dialog position="right"` / hand-built side panel | `TfSideSheet` |
| `$q.dialog` confirm | `TfConfirmDialog` (only if wiring is trivial) |
| Empty-state block | `TfEmptyState` (keep same title/message text) |
| Hand-built loading/error/empty wrapper | `TfQueryState` (only if the page already has all three states) |

### Button size must match its neighbors (required)

`TfBtn` defaults to `size="sm"` (dense, ~28px). Old `q-btn` next to fields was taller. Never let a swap shrink a button.

- Button in the same row/toolbar as a `q-input`/`q-select` (search, filters, "Create", "Add"): use `size="md"` (or `lg` if the field is `lg`) so its height matches the field. Do not use `sm` there.
- Keep the original padding/width classes (`q-px-*`, `col-auto`, `style="min-width"`) and `text-weight-*` on the new `TfBtn`.
- Icon-only buttons beside fields (filter, refresh): `variant="icon"` is 28px; if the field is taller, add `size="md"` or keep the original `q-btn` and list it as skipped.
- Row-action buttons inside cards/tables (copy, menu dots) may stay `sm`/icon.
- Before finishing, re-read each swapped button and its row: if the button looks shorter than the field beside it, raise size or revert that swap.

Do not touch: `q-card`, `q-input`, `q-select`, `q-table`, `q-chip`, `q-badge`, status chips/badges, colors.
`TfStatusBadge`: only swap when the user asks for it by name.

If a swap needs a missing variant, do not edit `ui/Tf*.vue` — skip and report.

## Step 3 — Spacing (allowed)

- Fix obvious uneven gaps using `q-pa-sm|md`, `q-gutter-sm`, `q-mt-*`.
- Replace `q-pa-lg|xl` with `q-pa-md` only on page/section wrappers.
- Do not change font sizes or component sizes.

## Step 4 — Skeleton / loading (allowed)

| Found | Do |
|---|---|
| Spinner / blank while first load | `<TfSkeletonRows v-if="isLoading && !items.length" :rows :cols/>` |
| Filter/search/page change refetch | Keep old list visible; `placeholderData: keepPreviousData` in its query; dim list with `isPlaceholderData` (opacity .6) |

Match skeleton rows/cols to the real list shape. Do not add optimistic updates, hints, help links, or banners.

## Step 4b — Dark mode safety (allowed, required)

Dark tokens live in `app.scss` (`body.body--dark`). Pages must not carry their own dark palette. Only touch colors that break dark mode; keep light look identical.

| Found in page | Replace with |
|---|---|
| Page's own `body.body--dark ...` block with hex (`#1c1917`, `#24201d`, `#2a2622`, `#262626`, ...) | Tokens, same selectors: surface `var(--tf-neutral-surface)`, page bg `var(--tf-neutral-canvas)`, border `var(--tf-neutral-border)` / `-strong`, text `var(--tf-neutral-ink)`, muted `var(--tf-neutral-muted)`, chip/disabled bg `var(--tf-disabled-bg)` |
| Hardcoded light hex in scoped CSS (`#fff`, `#f1f5f9`, `#e2e8f0`, `#64748b`, `#0f172a`, `rgba(0,0,0,.08)`) | Same-meaning token: `#fff`→surface, `#f1f5f9`→`--tf-disabled-bg`, `#e2e8f0`→border, `#64748b`→muted, `#0f172a`→ink |
| Success/warn/error tints (`#ecfdf5`, `#047857`, ...) | `--tf-success-soft`/`--tf-success` (same for warning/error/info) |
| Scope accent / primary text | `var(--tf-theme-primary)`; on primary fill use `var(--tf-theme-on-primary)` |
| Chart/tooltip colors | `--tf-viz-*`, surface/ink tokens |
| `text-grey-*`, `bg-white`, `bg-grey-*` | Leave: dark remaps them globally in `app.scss` |

Never use warm browns/stone hex or green/teal as dark surfaces. Each scope keeps its own primary (platform indigo, app slate, shop blue, investor navy); never hardcode it.
Token fallbacks in `var(--x, #hex)` are fine.

## Step 5 — Verify once

`ReadLints` on edited files only. Reply:
`Done` + one line: skipped swaps (if any).

## Never

Edit `app.scss` or `ui/Tf*.vue`. Add a page-level `body--dark` palette. Read whole >500-line files. Start servers. Run full typecheck. Touch more than one page per run. Restyle.

Usage: `/refactor-page-ui web/src/modules/<module>/pages/<Page>.vue`
