# Brand Visual Identity — Implementation Plan

Plan to unify **theme**, **color**, **font**, **splash screen**, and **brand logo** for BrandWala / TradeFlow BD.

**Status:** **Complete** — P0–P5 shipped (color, fonts, logo, splash, theme polish, doc sync).

**Canonical token reference:** [`docs/UI_CONSISTENCY.md`](./../docs/UI_CONSISTENCY.md)

---

## Problem (resolved 2026-08-25)

Previously the product told **three different brand stories** at once (violet splash, terracotta Quasar vars, cool-slate / Supabase-green app chrome). That drift showed on every load: splash → first screen.

**Shipped north star:** One warm, ledger-trustworthy canvas; four quiet accent lanes for *place*; one strict semantic palette for *state*; Plus Jakarta for words, IBM Plex Mono for money.

| Layer (before) | Issue | Shipped |
|----------------|-------|---------|
| Splash | Violet / heavy blobs | Warm stone canvas, compact logo, scope tagline |
| `app.scss` | Cool slate + Supabase emerald scopes | Warm neutrals + oxide burgundy / trade teal / commerce indigo / capital teal |
| Fonts | Roboto bundle + misaligned decimals | Jakarta + Plex Mono (`.bw-tabular`) + Noto Sans Bengali |

---

## Scope of work (what we are changing)

| Area | Goal |
|------|------|
| **Color** | One neutral foundation + semantic tokens + refined scope accents |
| **Theme** | Scope chrome, shadows, shop vs app rhythm, dark mode parity |
| **Font** | UI + tabular mono + Bengali; drop redundant bundles |
| **Splash** | Align with unified palette; reuse shared logo asset |
| **Brand logo (light)** | Official TradeFlow BD raster lockup for splash, favicon, auth, shell, about |

---

## Phase overview

| Phase | Focus | Risk | Est. files |
|-------|--------|------|------------|
| **P0** | Color tokens + semantic layer | Done | ~4 |
| **P1** | Fonts | Done | ~4 |
| **P2** | Light-theme logo + favicon (PNG) | Done — raster assets + references | ~8 |
| **P3** | Splash screen | Done — full lockup on splash | ~2 |
| **P4** | Theme polish (shell, tables, shop) | Done | ~5 |
| **P5** | Doc sync | Done | ~2 |

Implement P0 → P1 → P2 → P3 in order. P4 can ship incrementally per module.

---

## 1. Color

### Why

Wholesale ERP is invoices, ledgers, and warehouse labels. Cool slate (`#eef0f4`) reads “developer dashboard.” Warm stone reads “desk you trust with money.” Scope colors must signal **where you are**, not **success / error**.

### What (target token model)

#### Neutrals (shared across all scopes)

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `--bw-neutral-canvas` | `#fbfaf7` | `#141210` | Page background |
| `--bw-neutral-surface` | `#ffffff` | `#1c1917` | Cards, tables |
| `--bw-neutral-border` | `#e7e1d8` | `#2a2622` | Borders |
| `--bw-neutral-ink` | `#171412` | `#f5f5f4` | Body text |
| `--bw-neutral-muted` | `#736a61` | `#a8a29e` | Captions, meta |
| `--bw-neutral-chrome` | `#64748b` | `#94a3b8` | Table headers, overlines only |

Map existing `--bw-brand-*` and `--bw-theme-*` to these names (or alias them) so components keep working during migration.

#### Semantic (state — never reuse as scope primary)

| Token | Light | Use |
|-------|-------|-----|
| `--bw-success` | `#1A7F4B` | Posted, paid, in stock |
| `--bw-warning` | `#B45309` | Pending, low stock, draft |
| `--bw-error` | `#B83A3A` | Failed, voided, overdue |
| `--bw-info` | `#2563EB` | Info banners, links |
| `--bw-success-soft` etc. | 12% color-mix on surface | Row hues, banners |

#### Scope accents (place — four app surfaces)

| Scope | Current (light) | Target (light) | Target (dark) | Why change |
|-------|-----------------|----------------|---------------|------------|
| **Platform** | `#7f1d1d` | `#6B2D3C` oxide burgundy | `#E8A0A8` (muted) | Authority without “danger red” |
| **App** | `#047857` | `#0D6B5C` trade teal | `#4DB8A4` | Ops/growth; not Supabase clone |
| **Shop** | `#1e3a8a` | `#3D52B0` commerce indigo | `#7BA3F0` | Open B2B catalog, not navy corporate |
| **Investor** | `#0f766e` | `#0F5C5A` capital teal | `#5ECFC4` | Finance dignity; optional gold soft `#F5E6C8` at 8% on stat cards |

### What to change

| File | Change |
|------|--------|
| `web/src/css/app.scss` | Replace `:root` neutrals; update `.theme-platform` / `.theme-app` / `.theme-shop` / `.theme-investor`; add `--bw-success` … `--bw-info` + soft variants; tone down dark-mode neon primaries |
| `web/src/css/quasar.variables.scss` | Align `$positive`, `$negative`, `$warning`, `$info` with semantic tokens |
| `web/src/css/app.scss` | Stat cards: use semantic tokens instead of `#e53935` / `#2e7d32` |
| `web/src/css/app.scss` | Ops column tints: same hues at 6–8% background + 1px left accent (not full candy blocks) |
| `docs/UI_CONSISTENCY.md` | Update color tables to match shipped tokens |
| `.cursor/rules/.ui-consistency.mdc` | Mirror token list if rule references hex values |

### Acceptance

- [x] Light and dark neutrals feel warm, not Supabase-gray
- [x] Platform nav does not look like an error state
- [x] Green snackbar, green stat card, and app scope primary are visually distinct roles
- [x] No new hardcoded hex in touched components (tokens only)

---

## 2. Theme

### Why

Scopes already swap `--bw-theme-primary`, but surfaces, shadows, and density are identical everywhere. Shop buyers and warehouse staff need different rhythm. Tables use heavy triple shadows that make every list feel like a marketing card.

### What

1. **Scope identity** — scope primary on nav active soft-fill, shop bottom-nav pill, and splash accent glow (no header badge or drawer rail).
2. **Elevation rules**
   - **Flat:** data tables, list toolbars (border + single subtle shadow or inset only)
   - **Raised:** dialogs, drawers, clickable product cards, empty-state CTAs

3. **Shop layout theme** (`theme-shop`)
   - More padding on catalog/cart pages
   - Product titles `1.125rem / 600`; keep app tables at `0.875rem`
   - Bottom nav active = soft filled pill, not solid primary block

4. **Compact density toggle**
   - When on: `13px` body, `11px` meta, tighter stat values — not only shorter table rows

5. **Dark mode**
   - Same scope identity as light, ~85% saturation (no `#3ecf8e` neon)
   - Warm black base `#141210`, not pure `#171717`

### What to change

| File | Change |
|------|--------|
| `web/src/components/WorkspaceShell.vue` | Nav active + shop bottom nav use `--bw-theme-primary-soft`; mini drawer icon centering |
| `web/src/css/app.scss` | Flatten `.q-table__container` shadow stack; card hover only on `.cursor-pointer` |
| `web/src/composables/useAppearance.ts` | Optional: density affects CSS class on `body` (`bw-density-compact`) |
| Shop pages under `web/src/modules/shop_order/pages/` | Spacing + title scale via `.theme-shop` scoped rules |
| `docs/UI_CONSISTENCY.md` | Document elevation rules and shop rhythm |

### Acceptance

- [x] User can identify scope within 2 seconds without reading the URL
- [x] 40-row ops table feels stable (no “floating spreadsheet”)
- [x] Shop catalog feels slightly more open than app invoice desk

---

## 3. Font

### Why

Plus Jakarta Sans is already the UI voice — good. Numbers in P&L and ledger tables need **tabular alignment**; misaligned decimals erode trust faster than wrong border radius. Bengali locale needs a proper pairing. Roboto is still bundled via Quasar extras but barely used.

### What (target stack)

| Role | Family | Weights | Use |
|------|--------|---------|-----|
| **UI** | Plus Jakarta Sans | 400, 500, 600, 700 | All interface text |
| **Data / money** | IBM Plex Mono | 400, 500, 600 | Currency, qty, cost, barcodes, stat values |
| **Bengali** | Noto Sans Bengali | 400, 600 | When `locale === 'bn'` |

CSS:

```css
--bw-font-ui: 'Plus Jakarta Sans', system-ui, sans-serif;
--bw-font-mono: 'IBM Plex Mono', ui-monospace, monospace;
--bw-font-bn: 'Noto Sans Bengali', var(--bw-font-ui);

.bw-tabular {
  font-family: var(--bw-font-mono);
  font-variant-numeric: tabular-nums lining-nums;
}
```

#### Type scale (enforce)

| Tier | Size | Weight | Use |
|------|------|--------|-----|
| Display | `1.25–1.35rem` | 700 | Page title, hero KPI |
| Body | `0.875rem` (14px) | 400–500 | Tables, forms |
| Meta | `0.6875rem` (11px) | 600 + tracking | Overlines, column headers |

Change table body from `0.84rem` → `0.875rem`. Reserve **700** for titles and KPI numbers only.

### What to change

| File | Change |
|------|--------|
| `web/index.html` | Add Google Fonts links for IBM Plex Mono + Noto Sans Bengali |
| `web/quasar.config.ts` | Remove `roboto-font` from extras if Jakarta covers Latin |
| `web/src/css/app.scss` | Font variables; `.bw-tabular`; body `font-family`; Bengali `html[lang="bn"]` override |
| `web/src/css/app.scss` | `.stat-value` → mono + tabular nums |
| Costing / treasury / wallet tables | Replace ad-hoc `font-mono` with `.bw-tabular` |
| `web/src/components/WorkspaceShell.vue` | `.locale-bn` uses `--bw-font-bn` |
| `docs/UI_CONSISTENCY.md` | Typography section: Jakarta + Plex Mono, not Roboto |

### Acceptance

- [x] Ledger and invoice columns align on decimal places
- [x] Bengali header/locale selector does not look cramped
- [x] Font payload reduced or flat (no duplicate Latin stacks)

---

## 4. Splash screen

### Why

Splash is the first brand moment. Scope accent blobs still differ from `app.scss` until P0 ships. Favicon and splash now use the official light-theme PNG assets.

### What

1. **Single source of truth** for scope accent hex (shared constants or imported JSON — avoid duplicating a third palette).
2. **Neutral canvas** matches app: warm stone gradient, not violet-by-default.
3. **Logo** from `web/public/brand/logo-light.png` (full lockup with emblem + wordmark).
4. **Copy**
   - Product name is baked into the logo image; show tenant name when resolved
   - Scope-specific tagline from `SCOPE_THEMES` (no giant ghost word, no accent blobs)
5. **Motion** — subtle rise animation; reduced glow in dark mode
6. **Logo size** — compact lockup (`~44–58px` height), not full-bleed hero
7. **Favicon** — `favicon-light.png` / `favicon-dark.png` via `useDynamicFavicon` + `useAppearance`

### What to change

| File | Change |
|------|--------|
| `web/index.html` | Align `SCOPE_THEMES` hex with §1 scope table; default theme = warm stone + trade teal |
| `web/index.html` | Splash `<img src="/brand/logo-light.png">` |
| `web/index.html` | `theme-color` meta = neutral canvas in light mode |
| `web/src/boot/splash.ts` | No change expected; verify hide timing after asset load |
| `web/public/brand/` | `logo-light.png`, `logo-mark-light.png`, `favicon-light.png`, `logo-dark.png`, `logo-mark-dark.png`, `favicon-dark.png` |
| `web/src/constants/brandAssets.ts` | Canonical paths for Vue surfaces |
| `web/src/composables/useBrandAssets.ts` | Theme-aware logo src for components |

### Acceptance

- [x] Splash shows official TradeFlow BD lockup (not inline SVG builder)
- [x] Favicon uses emblem PNG in light appearance
- [x] Splash → first painted app screen: no visible color jump on neutrals (needs P0)
- [x] Platform / app / shop / investor splash accents match in-app scope primary

---

## 5. Light-theme brand logo (PNG)

### Why

The product needed one official mark. Generated SVG iterations were removed. The approved **TradeFlow BD** circular emblem + wordmark is shipped as raster PNGs for light surfaces.

### What (shipped assets)

| Asset | Path | Use |
|-------|------|-----|
| Full lockup | `web/public/brand/logo-light.png` | Splash, auth canvas, shell drawer (expanded), About dialog |
| Emblem crop | `web/public/brand/logo-mark-light.png` | Shell drawer (mini), compact surfaces |
| Favicon | `web/public/brand/favicon-light.png` | Browser tab icon in light appearance |
| Full lockup (dark) | `web/public/brand/logo-dark.png` | Same surfaces when dark mode |
| Emblem crop (dark) | `web/public/brand/logo-mark-dark.png` | Shell drawer mini in dark mode |
| Favicon (dark) | `web/public/brand/favicon-dark.png` | Browser tab icon in dark appearance |

**Constants:** `web/src/constants/brandAssets.ts` — light + dark path exports.

**Composable:** `web/src/composables/useBrandAssets.ts` — picks logo/mark/favicon from `useAppearance().darkMode`.

### What changed

| File | Change |
|------|--------|
| `web/public/brand/*.png` | Official raster assets (SVGs removed) |
| `web/src/constants/brandAssets.ts` | **Created** path constants |
| `web/index.html` | Splash + default favicon |
| `web/src/composables/useDynamicFavicon.ts` | Light/dark PNG favicons from `brandAssets.ts` |
| `web/src/composables/useAppearance.ts` | Re-sync favicon on dark-mode toggle |
| `web/src/layouts/AuthLayout.vue` | Full lockup on login canvas |
| `web/src/components/WorkspaceShell.vue` | Drawer logo when light mode |
| `web/src/components/navigation/AboutSystemDialog.vue` | Full lockup in header |

### Acceptance

- [x] Logo readable at favicon (32px) and splash (compact lockup)
- [x] Light-theme surfaces use PNG lockup via shared constants
- [x] Dark-theme surfaces use matching dark PNG lockup

---

## P5 — Doc sync

| File | Change |
|------|--------|
| `docs/UI_CONSISTENCY.md` | Canonical neutrals, semantic, scope, typography, elevation, shop rhythm, brand assets |
| `.cursor/rules/.ui-consistency.mdc` | Token + elevation rules for agents |
| `.agents/rules/table_list_design_system.md` | Canvas / dark mode / flat table surfaces |
| `doc/BRAND_THEME_PLAN.md` | This file — status + shipped vs planned notes |

### Acceptance

- [x] No doc still prescribes Roboto, Supabase-gray canvas, or old scope hex as canonical
- [x] `docs/UI_CONSISTENCY.md` matches `web/src/css/app.scss` token names

---

## File checklist (master)

```
web/src/css/app.scss              ← neutrals, scopes, semantic, tables, fonts
web/src/css/quasar.variables.scss ← Quasar semantic alignment
web/index.html                    ← splash, fonts, favicon, scope theme sync
web/quasar.config.ts              ← font extras
web/public/brand/logo-light.png   ← full lockup (light theme)
web/public/brand/logo-mark-light.png← emblem crop
web/public/brand/favicon-light.png← tab icon (light theme)
web/public/brand/logo-dark.png     ← full lockup (dark theme)
web/public/brand/logo-mark-dark.png← emblem crop (dark)
web/public/brand/favicon-dark.png  ← tab icon (dark theme)
web/src/constants/brandAssets.ts  ← canonical paths
web/src/composables/useBrandAssets.ts
web/src/components/WorkspaceShell.vue
web/src/layouts/AuthLayout.vue
web/src/components/navigation/AboutSystemDialog.vue
docs/UI_CONSISTENCY.md
doc/BRAND_THEME_PLAN.md           ← this file (update status when done)
```

---

## Testing plan

1. **Scopes** — Load `/superadmin`, `/:slug/app`, `/:slug/shop`, `/:slug/investor`; verify accent, splash, favicon alignment.
2. **Modes** — Toggle dark mode in shell; re-check tables, splash preference, logo contrast.
3. **Locales** — `bn` locale: Bengali script in nav, splash, cart.
4. **Data pages** — Costing file table, treasury stat grid, wallet ledger: decimal alignment.
5. **Performance** — Compare font bundle weight before/after dropping Roboto.
6. **Mobile** — Shop bottom nav, splash safe areas, favicon on home-screen add (Capacitor if applicable).

---

## Out of scope (this plan)

- Per-tenant white-label logos (shop `shop_logo_url` stays separate)
- Marketing site / email templates
- Regenerating tenant-uploaded assets in Cloudinary
- Changing module layouts or component placement (see UI consistency LOCKED rules)

---

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-25 | Warm stone neutrals over cool slate for ERP trust |
| 2026-08-25 | Scope color = place; semantic color = state — never mix |
| 2026-08-25 | Plus Jakarta + IBM Plex Mono; drop Roboto bundle |
| 2026-08-25 | Evolve 4-tile mark into shared SVG; drop inline `buildIconMarkup` |
| 2026-08-25 | Product display name on splash: **TradeFlow BD** unless tenant resolved |
| 2026-08-25 | Ship official TradeFlow BD PNG lockup for light theme; remove generated SVGs |
| 2026-08-25 | Splash redesign: compact logo, tagline, warm glow (no blobs/ghost) |
| 2026-08-25 | Scope chrome: soft nav fill only (no header badge / drawer rail) |

---

| 2026-08-25 | Ship matching dark-theme PNG lockup + `useBrandAssets` composable |
| 2026-08-25 | P5 doc sync — `UI_CONSISTENCY.md` + agent rules aligned to shipped tokens |
