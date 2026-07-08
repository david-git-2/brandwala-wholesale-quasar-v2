# UI Consistency Guide

## Purpose

This document defines the UI pattern that should be followed when building or updating pages in the Quasar app.

The goal is simple:

- keep page flow consistent
- keep cards consistent
- keep tables consistent
- avoid one-off page layouts
- give AI a clear pattern to follow

This guide should be used whenever a new admin, platform, app, or shop page is created.

## Core Rule

Do not build raw page layouts from scratch if the page fits an existing shared pattern.

Prefer Quasar default components first.

Global layout helpers and shared tokens live in:

- [`web/src/css/app.scss`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/css/app.scss)

## Standard Page Flow

For list, catalog, and management pages, use this order:

1. `q-page` with class `bw-page`
2. wrapper with class `bw-page__stack`
3. simple page heading
4. optional `q-banner` for error state with class `bw-status-banner`
5. `q-card` when a section container is needed
6. one of:
   - `q-card` grid
   - `q-table`
   - direct section content
7. simple empty state text or a `q-card` empty section

Do not scatter unrelated floating actions around the page unless there is a strong product reason.

## Shared Patterns

Use Quasar defaults:

- page heading with normal text elements
- `q-card` for grouped sections
- `q-table` for row-based data
- plain text empty states when enough

## Design Rules

### Layout

- use `bw-page` for page padding
- use `bw-page__stack` for vertical rhythm
- use `bw-entity-grid` for standard card grids
- use `bw-inline-actions` for grouped action buttons
- keep sections left-aligned and business-oriented
- use fewer wrapper `div`s
- prefer semantic tags or Quasar sections when they already fit

### Content Density

- tenant and module pages are management screens, not marketing pages
- keep them clean and structured
- avoid oversized decorative areas
- avoid deeply nested cards

### Buttons

- one primary action is enough in most headers
- use secondary buttons only when truly needed
- for the app flow, do not add refresh buttons by default
- do not add floating FABs if the same action can live clearly in the header
- use default Quasar `q-btn` styles
- keep button text short and action-based

### Cards

- use plain `q-card`
- keep content simple
- avoid custom card shells

### Tables

- use `q-table`
- keep column labels short
- prefer explicit operational actions
- keep empty handling simple

### Simple Entry Screens

For small input-plus-list screens:

- prefer native Quasar building blocks like `q-card`, `q-input`, `q-btn`, and `q-markup-table`
- keep only the important text
- use theme colors instead of one-off colors
- avoid decorative wrappers when a plain Quasar layout is enough
- do not add custom visual styling if Quasar default already works

## Theme Rules

The app already has shared visual tokens in:

- [`web/src/css/app.scss`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/css/app.scss)
- [`web/src/components/WorkspaceShell.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/WorkspaceShell.vue)

Follow these rules:

- use existing theme variables
- use `var(--bw-theme-...)` tokens
- do not hardcode unrelated colors unless needed for status or domain-specific meaning
- keep platform, app, and shop visually related but theme-aware
- do not override Quasar defaults globally unless there is a real product need

## What AI Should Do

When asked to build a new UI page, AI should:

1. check whether the page is a list page, detail page, form page, or data table page
2. use Quasar defaults before creating new abstractions
3. keep the page flow consistent with tenant and module pages
4. add new shared UI only when the pattern is truly reusable
5. avoid introducing new one-off card styles for common business entities

## What AI Should Not Do

Avoid these mistakes:

- building custom wrapper components when plain Quasar components already fit
- adding refresh buttons by default in app management pages
- using floating sticky buttons for common create actions when header actions are enough
- mixing multiple layout styles on similar CRUD pages
- using plain text empty states without guidance
- hardcoding colors that ignore the existing theme tokens
- adding custom visual treatments when default Quasar UI is enough

## Reference Pages

Use these pages as the current reference implementation:

- [`web/src/modules/tenant/pages/TenantPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/pages/TenantPage.vue)
- [`web/src/modules/tenant/pages/AdminTenantPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/pages/AdminTenantPage.vue)
- [`web/src/modules/featureCatalog/pages/ModulesPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/featureCatalog/pages/ModulesPage.vue)

These pages define the current standard for:

- page heading
- section layout
- card grid
- action placement

## Example Direction

### If the page is a simple management list

Use:

- `AppPageHeader`
- `AppSectionCard`
- `AppEntityCard`
- `AppEmptyState`

### If the page is a dense operational screen

Use:

- `AppPageHeader`
- `AppDataTable`
- `AppEmptyState`

### If the page is a detail view

Use:

- `AppPageHeader`
- one or more `AppSectionCard` sections
- shared action placement

Try to keep the same spacing and structure as the list pages.

### If the page is a high-density operational detail view (e.g. Shipment Details, Costing File Details)

Follow the Compact Design pattern to maximize screen space:

- **Compact Padding**: Replace `bw-page` with class `q-pa-xs q-sm-pa-sm` on the `q-page` component. Replace `bw-page__stack` container with `q-gutter-y-sm` to tighten gap spacing.
- **Unified Hero Card Header**: Replace separate title headers with a single card layout containing ID badges, titles, and type/weight/ready metadata on the left, and actions/status chips on the right.
- **Compact Status Selector Chip**: Replace long stepper progress bars with a single interactive status `q-chip` next to the title (or on the right of the header card). Clicking the chip reveals a dropdown status list selector.
- **Icon-only Actions**: Avoid heavy button rows in the header card. Transition secondary details operations (like Edit, Delete) to flat, round, icon-only buttons with tooltips.
- **Collapsible Layout**: Place summaries, rates, or metrics panels in a collapsible left sidebar, allowing the primary data table on the right to expand to 100% width when collapsed.
- **Internal Table Scroll**: Add `table-style="min-width: 1200px;"` to data tables to force them to scroll horizontally within their card boundary, preventing layout stretching.
- **Table Column Pastel Highlights**: Highlight key columns in high-density tables using pastels to increase visual scannability: Package Weight is Purple (`#e8d7f7`), Price is Green (`#daf3e4`), Cost is Orange (`#ffe8d1`), and Quantity is Blue (`#d0e6ff`). All other columns remain neutral/transparent.
- **Footer Total Color Matching**: Ensure column background highlights extend all the way down to the table's total/summary footer row cells, keeping columns colored consistently.
- **Stacked Unit and Total Cell Values**: Render unit values and total values stacked inline in table cells for columns like Price, Cost, Product Weight, and Package Weight (prefixed with `T: ` for the total value).
- **Standardized Weights**: Keep unit weights and table totals in grams (`gm`) for operational clarity in high-density tables.
- **Inline Quantity Split Workflow**: When in `Warehouse Received` status, add a Split Qty action column next to the Product ID. Showing Done/Pending badges (Done green, Pending orange) and clicking the button prompts a centered screen dialog featuring a product image, name, and input fields to allocate stock.

## Treasury Layout and Overflow Rules

For treasury and reporting pages under the `reporting_treasury` module, follow these layout guidelines to avoid table overflow and maintain high visual consistency:

- **TreasuryPageShell Flow**: Standard treasury detail and list pages follow a strict top-to-bottom layout flow:
  1. **Page Header / Hero**: Title, status chips, search input/filters.
  2. **TreasuryStatGrid**: 4 to 6 metric cards displaying high-level totals.
  3. **Data Tables**: Wrapped in scroll containers.
- **TreasuryTableWrap**: Always wrap all `q-table` elements in a `TreasuryTableWrap` container component to handle horizontal overflows. The wrapper must have `min-width: 0` and `width: 100%`, and the inner `.q-table__middle` target must be set to `overflow-x: auto` to prevent page-level horizontal bleed.
- **Min-Width Tables**: Define explicit minimum widths (e.g., `table-style="min-width: 900px"` or `1100px` depending on column count) directly on the tables to enforce horizontal scroll inside the card boundary, preventing narrow column squishing.
- **Card and Stack Constraints**: Ensure any parent container cards have class `overflow-hidden` and `style="min-width: 0"`. The root `.bw-page` must have `overflow-x: hidden` and `max-width: 100%`, and the `.bw-page__stack` container must specify `min-width: 0` so grid/flex items can shrink correctly.
- **Explicit Stat Formatting**: Ensure `TreasuryStatGrid` cards declare the correct type of metric format (e.g., `percent`, `currency`, `number`) to guarantee proper unit rendering.
- **Split P&L Layout**: Avoid combining trading profit/loss figures and warehouse disposition metrics into a single layout. Divide them into a Trading P&L table and a Stock Disposition table.

## When To Create A New Shared Component

Create a new shared UI component only if:

- the pattern appears in at least two pages
- it solves a real consistency problem
- it is more than a one-page visual tweak

If a page is unique, keep the uniqueness inside the page.
If many pages need the same pattern, move it into `web/src/components/ui`.

## Summary

The design system for this app is now:

- shared header
- shared section shell
- shared entity card
- shared empty state
- shared table shell
- shared page spacing and theme tokens

Future UI work should extend this system instead of bypassing it.
