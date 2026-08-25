# List Table Design System & Layout Rules

These canonical rules govern the layout, density, and styling of table list and workflow pages (e.g., Inbound Shipments, Invoices, Orders, Stock Lists, Shops).

## 1. Zero In-Page Headers (Mandatory Screen Real-Estate Rule)
- **No In-Page Title Banners**: Do NOT render standalone in-page header sections (`<h1>`, `text-overline`, `AppPageHeader`, or standalone back buttons). Page titles and breadcrumb hierarchies are handled globally by the **Top Breadcrumb Navigation** in the App Header (`useBreadcrumbs` / `usePageBreadcrumbs`).
- **Always Remove Legacy In-Page Headers**: When creating, updating, or reviewing any page, AI agents MUST remove legacy in-page headers, overlines, and standalone back buttons to maximize vertical screen real estate for data.
- **Unified Compact Toolbar**: Primary action buttons (e.g., "Add Shipment", "Create Shop"), search inputs, filter pills/tabs, and guide buttons MUST live together in a single compact 38px toolbar directly attached to the table/view.

## 2. Fixed Outer Layout & Internal Table Scroll
- **Zero Outer Page Scroll**: Set `q-page` container height to `calc(100vh - 55px)` with `overflow: hidden` (`.page-fixed-layout` or `.bg-grey-1 column no-wrap`). The outer browser window should never scroll on table list pages.
- **Internal Table Scroll**: The table wrapper (`.treasury-table-wrap`) must flex to take up remaining height (`flex: 1 1 0%`, `overflow: hidden`), allowing `.q-table__middle` to scroll internally.
- **Sticky Column Headers**: Table headers must remain pinned at the top while table body rows scroll (`thead tr th { position: sticky; top: 0; z-index: 2; }`). Use `--bw-neutral-chrome` for header text and a surface mix for header background — see `docs/UI_CONSISTENCY.md`.

## 3. Compact & Denser Controls
- **Search Input**: Use `outlined rounded dense` inputs (`<q-input outlined rounded dense placeholder="...">`).
- **Primary Action Buttons**: All buttons use **rounded square** corners (`border-radius: 8px`) globally via `.q-btn`, `.pill-btn`, and `.square-btn` in `app.scss`. Do not override with pill/circle shapes.

## 4. Status High-Visibility & Row Background Hues
- **Status Background Hues**: Table rows (`<q-tr>`) MUST feature a subtle background hue/tint based on the record's status, with full dark mode support:
  - *Draft*: Light mode `#fffdf5` / Dark mode `rgba(245, 158, 11, 0.08)` + Amber left accent bar (`#f59e0b`)
  - *In Transit*: Light mode `#fffbf7` / Dark mode `rgba(249, 115, 22, 0.08)` + Orange left accent bar (`#f97316`)
  - *Received / Completed*: Light mode `#f6fcf8` / Dark mode `rgba(34, 197, 94, 0.08)` + Emerald left accent bar (`#22c55e`)
  - *Cancelled*: Light mode `#fef7f7` / Dark mode `rgba(239, 68, 68, 0.08)` + Rose red left accent bar (`#ef4444`)
- **Row Accent Border**: Include an inset left accent bar on rows (`boxShadow: inset 3px 0 0 <accentColor>`).
- **Status Column & Chips**: Render status and type chips using **square chips with soft radius** (`border-radius: 6px`, `square dense`), with status-specific icons, bold uppercase text, and matching background/border (`.shipment-status-badge`).

## 5. Single-Location Information & Entity Avatars
- **No Duplicate Renderings**: Do NOT render status or type tags inside the ID column if dedicated Status or Type columns exist in the table.
- **Entity & Vendor Avatars**: Render entity/vendor avatars using a **square avatar with soft radius** (`square` or `rounded` with `border-radius: 6px`), with clean neutral grey tones (`q-avatar` with `color="grey-3" text-color="grey-9"`).
- **Row Actions Column**: Always include a right-aligned actions column (`ph ph-dots-three-vertical`) with dropdown options (*View Details*, *Edit Details*).

## 6. Flat Surfaces & Canvas (Brand tokens)
- **Canvas Backdrop**: Page container uses warm stone `--bw-neutral-canvas` / `var(--bw-brand-base)` (`#fbfaf7` light).
- **Flat table surfaces**: Prefer global `.q-table__container` styling (border + `0 1px 2px` shadow). Avoid triple-stack marketing shadows on ops lists. Toolbars: `.bw-page-toolbar` or `q-card flat bordered` — flat, not floating cards.
- **Dark mode**: Canvas `#141210`, surface `#1c1917`, border `#2a2622`, ink `#f5f5f4`, muted `#a8a29e`. Scope primary comes from `.theme-*` classes — not Supabase neon emerald.
- **Raised only when interactive**: Dialogs, drawers, clickable product cards, empty-state CTAs — see elevation rules in `docs/UI_CONSISTENCY.md`.
