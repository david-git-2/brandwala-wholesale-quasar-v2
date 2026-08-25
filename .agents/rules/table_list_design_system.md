# List Table Design System & Layout Rules

These canonical rules govern the layout, density, and styling of table list and workflow pages (e.g., Inbound Shipments, Invoices, Orders, Stock Lists, Shops).

## 1. Zero In-Page Headers (Mandatory Screen Real-Estate Rule)
- **No In-Page Title Banners**: Do NOT render standalone in-page header sections (`<h1>`, `text-overline`, `AppPageHeader`, or standalone back buttons). Page titles and breadcrumb hierarchies are handled globally by the **Top Breadcrumb Navigation** in the App Header (`useBreadcrumbs` / `usePageBreadcrumbs`).
- **Always Remove Legacy In-Page Headers**: When creating, updating, or reviewing any page, AI agents MUST remove legacy in-page headers, overlines, and standalone back buttons to maximize vertical screen real estate for data.
- **Unified Compact Toolbar**: Primary action buttons (e.g., "Add Shipment", "Create Shop"), search inputs, filter pills/tabs, and guide buttons MUST live together in a single compact 38px toolbar directly attached to the table/view.

## 2. Fixed Outer Layout & Internal Table Scroll
- **Zero Outer Page Scroll**: Set `q-page` container height to `calc(100vh - 55px)` with `overflow: hidden` (`.page-fixed-layout` or `.bg-grey-1 column no-wrap`). The outer browser window should never scroll on table list pages.
- **Internal Table Scroll**: The table wrapper (`.treasury-table-wrap`) must flex to take up remaining height (`flex: 1 1 0%`, `overflow: hidden`), allowing `.q-table__middle` to scroll internally.
- **Sticky Column Headers**: Table headers must remain pinned at the top while table body rows scroll (`thead tr th { position: sticky; top: 0; z-index: 2; color: #0f172a; font-weight: 700; background: #f8fafc; }`). Use default black text (`#0f172a` / `#171412`) for the header text.

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

## 6. Floating Surface & Ambient Shadow Elevation Aesthetic
- **Canvas Backdrop Contrast**: The page container features the modern neutral canvas background (`rgb(238, 240, 244)` / `var(--bw-brand-base)` / `#eef0f4`).
- **Floating Surface & Rounded Cards**: Tables, primary toolbars, and content surfaces MUST use `.floating-surface.shadow-1` (or sleek rounded corners `border-radius: 8px`, subtle border `1px solid rgba(226, 232, 240, 0.6)`, pure white surface `background: #ffffff`, and diffused ambient floating shadow `box-shadow: 0 20px 45px -10px rgba(51, 65, 85, 0.10), 0 10px 20px -5px rgba(51, 65, 85, 0.05), 0 2px 6px 0 rgba(51, 65, 85, 0.03)`).
- **Supabase Studio Dark Standard**: In dark mode, the canvas is Supabase Studio dark (`#171717`), surfaces adopt `#1c1c1c` with border `#2e2e2e`, row borders `#262626`, table header text in `#a1a1aa`, primary text in crisp `#ededed`, and emerald accents (`#3ecf8e`).
