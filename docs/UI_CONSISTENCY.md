# UI Consistency Reference

Canonical UI rules for the Quasar app. Machine-readable rules: `.cursor/rules/.ui-consistency.mdc`.

## Color tokens

### Brand (light `:root`)
| Token | Value |
|-------|-------|
| `--bw-brand-base` | `#fbfaf7` |
| `--bw-brand-surface` | `#ffffff` |
| `--bw-brand-border` | `#e7e1d8` |
| `--bw-brand-ink` | `#171412` |
| `--bw-brand-muted` | `#736a61` |
| `--bw-brand-accent` | `#7c3aed` |

### Brand (dark `body.body--dark`)
| Token | Value |
|-------|-------|
| `--bw-brand-base` | `#0c0a09` |
| `--bw-brand-surface` | `#1c1917` |
| `--bw-brand-border` | `#292524` |
| `--bw-brand-ink` | `#f5f5f4` |
| `--bw-brand-muted` | `#a8a29e` |
| `--bw-brand-accent` | `#a78bfa` |

### Semantic theme (use these in components)
- `--bw-theme-base`, `--bw-theme-surface`, `--bw-theme-border`, `--bw-theme-ink`, `--bw-theme-muted`
- `--bw-theme-primary`, `--bw-theme-primary-soft`, `--bw-theme-shadow`
- `--q-primary` maps to `--bw-theme-primary`
- Scope overrides: `.theme-platform` (red), `.theme-app` (emerald), `.theme-shop` (blue), `.theme-investor` (`#0f766e`)

### Domain table highlights (high-density ops tables only)
- Package weight: `#e8d7f7` | Price: `#daf3e4` | Cost: `#ffe8d1` | Quantity: `#d0e6ff`

Source: `web/src/css/app.scss`, `web/src/components/WorkspaceShell.vue`

## Typography

- Font family: **Roboto** (Quasar `roboto-font` extras)
- Mobile base: `html { font-size: 14px }` below 600px
- Page title (`AppPageHeader`): `1.35rem` / weight 700
- Eyebrow: `0.75rem`, uppercase, `--bw-theme-muted`
- Stat labels: `11px` | Stat values: `20px` / weight 700
- Table density: `11–13px` in compact operational tables
- Muted text utility: `.bw-text-muted` → `--bw-theme-muted`

## Spacing

- Page padding: `.bw-page` → `clamp(1rem, 2.4vw, 2rem)` (8px on mobile)
- Vertical stack: `.bw-page__stack` → `gap: 1.25rem`
- Card grid: `.bw-entity-grid` → `gap: 1rem`, `minmax(240px, 1fr)`
- Inline actions: `.bw-inline-actions` → `gap: 0.65rem`
- Stat cards: `padding: 12px 14px 10px`, `margin-bottom: 12px`
- `q-page` max-width: `1200px`, centered

## Border radius & shadows

| Element | Radius |
|---------|--------|
| `q-btn` | `8px` |
| `q-editor`, `.soft-input` | `8–10px` |
| `.stat-card` | `10px` |
| `.floating-surface`, `.empty-state-block` | `14px` |
| `.hero-surface` | `16px` |
| `.pill-btn` | `999px` |
| `.square-chip` | `4px` |

Shadow: `--bw-theme-shadow` (scope-specific; light: soft stone tint, dark: deeper black)

## Standard page flow

1. `q-page.bw-page`
2. `.bw-page__stack`
3. `AppPageHeader` (or simple heading)
4. Optional `q-banner.bw-status-banner` for errors
5. `q-card flat bordered` for sections
6. `q-table` or `.bw-entity-grid` card grid
7. Empty state (see below)

Prefer Quasar defaults. Do not build custom wrappers when `q-card` / `q-table` suffice.

## Component inventory

### Shared (`web/src/components/`)
| Component | Path | Description |
|-----------|------|-------------|
| `WorkspaceShell` | `components/WorkspaceShell.vue` | App shell, theme scope, nav layout |
| `GlobalAjaxBar` | `components/GlobalAjaxBar.vue` | Top progress bar for in-flight requests |
| `AppPageHeader` | `components/ui/AppPageHeader.vue` | Title, subtitle, eyebrow, action slot |
| `PageInitialLoader` | `components/PageInitialLoader.vue` | Full-page / overlay spinner (`q-spinner-tail`) |
| `PageInitialLoader` | `components/ui/PageInitialLoader.vue` | Same pattern (prefer consolidating imports) |
| `ModuleNavBadge` | `components/ui/ModuleNavBadge.vue` | Nav badge for module state |
| `RichTextEditor` | `components/ui/RichTextEditor.vue` | Themed `q-editor` wrapper |
| `SmartImage` | `components/SmartImage.vue` | Responsive image with fallback |
| `ImageLightbox` | `components/ImageLightbox.vue` | Fullscreen image viewer |
| `CloudinaryUploaderDialog` | `components/CloudinaryUploaderDialog.vue` | Cloudinary upload dialog |
| `FilterSidebar` | `components/FilterSidebar.vue` | Filter panel for list pages |

### Treasury (`web/src/modules/reporting_treasury/components/`)
| Component | Description |
|-----------|-------------|
| `TreasuryPageShell` | Header → stat grid → table layout for finance pages |
| `TreasuryStatGrid` | 4–6 metric cards with typed formatting |
| `TreasuryTableWrap` | Horizontal scroll wrapper for `q-table` |
| `TreasuryFilterBar` | Treasury-specific filters |

### Auth & reference patterns
| Component | Path | Description |
|-----------|------|-------------|
| `AuthLoginPanel` | `modules/auth/components/AuthLoginPanel.vue` | Scoped login panel |
| `ReferenceCatalogPage` | `modules/global_reference/components/ReferenceCatalogPage.vue` | CRUD list pattern for global refs |

### Reference pages (copy these patterns)
- `web/src/modules/tenant/pages/TenantPage.vue`
- `web/src/modules/tenant/pages/AdminTenantPage.vue`
- `web/src/modules/featureCatalog/pages/ModulesPage.vue`

## Button states

| State | Pattern |
|-------|---------|
| Primary | `q-btn color="primary" unelevated` — one per header max |
| Secondary | `q-btn flat` or `outline` |
| Danger | `q-btn color="negative"` or `flat color="negative"` |
| Disabled | `:disable="true"` on `q-btn` |
| Compact | `.slim-btn` (32px height) |
| Pill | `.pill-btn` for rounded CTAs |
| Icon-only (dense ops) | `flat round` + `q-tooltip` — secondary header actions |

No default refresh buttons on app management pages. No FABs when header action suffices.

## Form input states

- Default: Quasar `outlined` or `filled` matching surrounding page
- Themed: `.soft-input` on `q-field` (rounded control, surface mix background)
- Focus: inherit Quasar focus ring; do not add global box-shadow overrides on `q-editor`
- Error: field `error` + `error-message` props; page-level errors use `q-banner.bw-status-banner.bg-negative`

## Loading states

| Pattern | When |
|---------|------|
| `PageInitialLoader` | Initial page / store fetch (optionally `overlay` for actions) |
| `GlobalAjaxBar` | Background request progress (app-wide) |
| `q-skeleton` | In-table row placeholders (Thrift high-density tables) |
| `q-inner-loading` | Inline section loading (sparse use) |

No skeleton system app-wide — `PageInitialLoader` is the default for page-level loads.

## Empty states

| Pattern | When |
|---------|------|
| `.empty-state-block.floating-surface` | List pages with no rows (invoices, catalogs) |
| `column items-center … empty-state q-pa-xl` | Shop/customer empty lists |
| Plain muted text in `q-card` | Simple management screens |
| `q-banner.bw-status-banner` | Error / warning (not empty data) |

## Toast & alert patterns

Use `web/src/utils/appFeedback.ts` — do not call `Notify.create` ad hoc.

| Function | Type | Position | Timeout |
|----------|------|----------|---------|
| `showSuccessNotification` | positive | top-right | 2200ms |
| `showErrorNotification` | negative | top-right | 3000ms |
| `showWarningNotification` | warning | top-right | 2500ms |
| `showWarningDialog` | dialog | — | user dismiss |
| `requestConfirmation` | confirm dialog | — | persistent |
| `handleApiFailure` | warning dialog | — | on `success: false` |

## Layout utilities

- `.floating-surface` — elevated card surface (reports, empty states)
- `.hero-surface` — larger radius hero sections (investor/finance views)
- `.stat-card` (+ `--negative`, `--positive`, `--primary` variants)
- `.card-hover` — subtle lift on hover for selectable cards
- `.treasury-table-wrap` — alias pattern for table overflow (prefer `TreasuryTableWrap` component)

## Compact operational detail pages

For shipment/costing-style dense views:
- Tighter padding: `q-pa-xs q-sm-pa-sm` + `q-gutter-y-sm` instead of `bw-page__stack`
- Unified hero card header (metadata left, actions/status right)
- Status as interactive `q-chip` dropdown (not stepper)
- Collapsible side summary; main table expands full width
- Tables: `table-style="min-width: 1200px"` inside card for internal scroll

## Treasury pages

Flow: `TreasuryPageShell` → header/filters → `TreasuryStatGrid` → `TreasuryTableWrap` > `q-table`
- Parent cards: `overflow-hidden`, `min-width: 0`
- `.bw-page`: `overflow-x: hidden`, `max-width: 100%`
- Split Trading P&L and Stock Disposition into separate tables

## When to add shared components

Only when pattern appears on 2+ pages and solves a real consistency problem. Location: `web/src/components/ui/`.
