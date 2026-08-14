# List Table Design System & Layout Rules

These canonical rules govern the layout, density, and styling of table list pages (e.g., Inbound Shipments, Invoices, Orders, Stock Lists).

## 1. Fixed Outer Layout & Internal Table Scroll
- **Zero Outer Page Scroll**: Set `q-page` container height to `calc(100vh - 55px)` with `overflow: hidden` (`.page-fixed-layout`). The outer browser window should never scroll on table list pages.
- **Internal Table Scroll**: The table wrapper (`.treasury-table-wrap`) must flex to take up remaining height (`flex: 1 1 0%`, `overflow: hidden`), allowing `.q-table__middle` to scroll internally.
- **Sticky Column Headers**: Table headers must remain pinned at the top while table body rows scroll (`thead tr th { position: sticky; top: 0; z-index: 2; background: #f8fafc; }`).

## 2. Compact & Denser Spacing
- **Header & Overline**: Compact padding (`q-py-xs`), `text-overline` font size `10px`.
- **Search Input**: Use `outlined rounded dense` inputs (`<q-input outlined rounded dense placeholder="...">`).
- **Primary Action Buttons**: Primary buttons (e.g., "Add Shipment", "Create Invoice") MUST use **rounded-corner square** styling (`border-radius: 8px`), NOT pill shapes (`border-radius: 999px`).

## 3. Status High-Visibility & Row Background Hues
- **Status Background Hues**: Table rows (`<q-tr>`) MUST feature a subtle light background hue/tint based on the record's status:
  - *Draft*: Soft warm cream hue (`#fffdf5`) + Amber left accent bar (`#f59e0b`)
  - *In Transit*: Soft light orange tint (`#fffbf7`) + Orange left accent bar (`#f97316`)
  - *Received / Completed*: Soft light mint green tint (`#f6fcf8`) + Emerald left accent bar (`#22c55e`)
  - *Cancelled*: Soft light rose red tint (`#fef7f7`) + Rose red left accent bar (`#ef4444`)
- **Row Accent Border**: Include an inset left accent bar on rows (`boxShadow: inset 3px 0 0 <accentColor>`).
- **Status Column**: Render status using a high-visibility badge with a status-specific icon (`ph ph-note-pencil`, `ph ph-truck`, `ph ph-check-circle`, `ph ph-x-circle`), bold uppercase text, and status-matching pill border (`.shipment-status-badge`).

## 4. Single-Location Information & Entity Avatars
- **No Duplicate Renderings**: Do NOT render status or type tags inside the ID column if dedicated Status or Type columns exist in the table.
- **Entity & Vendor Avatars**: Render entity/vendor avatars using a clean neutral grey tone (`q-avatar` with `color="grey-3" text-color="grey-9"`).
- **Row Actions Column**: Always include a right-aligned actions column (`ph ph-dots-three-vertical`) with dropdown options (*View Details*, *Edit Details*).
