---
name: refactor-page-ui
description: Light UI pass on one Vue page. Swap to Tf* components, tidy spacing, add skeleton loading. Does NOT restyle fonts, sizes, row tints, or layout. Only recolors what breaks dark mode. Use when the user names a page/file and says refactor UI, apply components, or /refactor-page-ui.
---

# Refactor page UI (light pass)

Input: ONE `.vue` file (+ direct child list/card if the page only wraps it). Canon: `.cursor/rules/quasar-ui.mdc`. Do not open mega list pages.

## Scope — only

1. **Components** → shared `Tf*`
2. **Spacing** → `q-pa-sm|md`, `q-gutter-sm`; replace `q-pa-lg|xl` on wrappers with `q-pa-md`
3. **Skeleton / loading** → `TfSkeletonRows` / keepPreviousData dim
4. **Dark safety** → page-local dark hex / hard light hex → `--tf-neutral-*` / semantic softs per `quasar-ui.mdc`. No page `body.body--dark` palettes.

Do not change behavior, layout, row tints, fonts, or `ui/Tf*.vue` / `app.scss`.

## Swaps

| Found | Replace |
|---|---|
| `q-btn` actions | `TfBtn` (match field height: toolbar/search row → `size="md"`) |
| Icon-only `flat round dense` | `TfBtn variant="icon"` + tooltip |
| Filter tabs / pills | `TfDrawerSectionTabs` / Header |
| Right `q-dialog` | `TfSideSheet` |
| Empty block | `TfEmptyState` |
| Loading/error/empty wrapper | `TfQueryState` if page already has all three |

Skip any swap that changes look noticeably; list skipped in the Done line.

## Verify

`ReadLints` on edited files only. Reply: `Done` + skipped swaps (if any).
