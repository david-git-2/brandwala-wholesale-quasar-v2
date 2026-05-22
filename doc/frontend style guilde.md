# Frontend Style Guide: Costing List + Details Pattern

This guide documents the UI pattern used in:
- `web/src/modules/product_based_costing/pages/ProductBasedCostingPage.vue`
- `web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue`

Use this as the standard pattern when updating other pages.

## 1) Page Shell Pattern

Use a page container with transparent background and consistent spacing:

- `q-page` with `q-pa-md`
- page class: `costing-list-page` or `costing-details-page`
- style:
  - `background: transparent;`

## 2) Surface/Card Pattern

Use floating glass-like cards for all major sections.

### Required utility classes

- `floating-surface`
- `hero-surface` for top header card
- `shadow-1`

### CSS

```css
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}
```

## 3) Header Pattern

Top area should have:
- left: title + subtitle (or back button + file meta in details)
- right: primary action buttons

### Title style
- `text-h6 text-weight-bold`
- subtitle: `text-caption text-grey-8`

### Back navigation rule
- Do not add page-level back buttons when the app layout already provides header back navigation.
- Use the shared layout header back button as the default navigation pattern.
- Only add local back buttons for standalone pages that do not use the shared layout header.

## 4) Action Button Style Pattern

### Primary pill button
Use for "Create", "Save", "Add Item", etc.

- props: `color="primary" no-caps size="sm"`
- classes: `pill-btn slim-btn`

```css
.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}
```

## 5) Search + Filter Toolbar Pattern (List Pages)

Use a compact toolbar row:
- Search icon toggles search input
- Filter icon opens sidebar/drawer
- Active filter badge count on filter icon
- View mode toggle on right (table/grid)
- Keep search hidden by default; show input only after clicking search icon.

### Search input style
- `outlined dense`
- classes: `soft-input toolbar-search`
- prepend search icon
- append close icon button
- `clearable`, `autofocus`
- include close icon in append slot to hide search and reset search text

```css
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}
```

## 6) Filter Drawer Pattern

Use shared `FilterSidebar` component:
- title: `Filters`
- `q-select` for status or other filters
- `outlined dense` + `soft-input`
- reset action aligned right inside the drawer (not in main toolbar)
- For list/cart pages, prefer placing filter controls inside `FilterSidebar` instead of inline rows to keep a consistent compact toolbar.

## 7) Table Pattern

For list table:
- Wrap in `q-card.flat.floating-surface.shadow-1`
- use `q-table flat`
- row click opens details
- top headers subtle background tint

```css
.costing-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
```

## 8) Table Behavior (Height, Scroll, Column Selector)

Use this behavior for details pages and data-heavy list pages.

### Height and scroll
- Keep table inside floating card and apply a fixed viewport height to table middle area.
- Enable internal scroll on table body; header stays visible.
- Use sticky columns only where needed (example: `SL`, `Image`, `Name`).
- Keep horizontal scroll enabled when many columns exist.

```css
.costing-page__table :deep(.q-table__middle) {
  max-height: calc(100vh - 320px);
  overflow: auto;
}

.costing-page__table :deep(.q-table) {
  table-layout: fixed;
}
```

If a page has an extra toolbar/filter area, reduce the available table height:
- example pattern: `max-height: calc(100vh - 360px)` or `calc(100vh - 400px)` as needed.

### Column selector (required pattern)
- Add a `Columns` button in header actions.
- In menu:
  - `Select / Deselect All` checkbox
  - `q-option-group` checkbox list for selectable columns
- Keep core columns always visible (for example: `actions`, `sl`, `image`, `name`).
- Keep selected columns in a reactive array (`selected...ColumnNames`).
- Build visible list as:
  - `alwaysVisible + selectedSelectable`
- Bind table with:
  - `:columns="allColumns"`
  - `:visible-columns="visibleColumnNames"`
- For totals row/footer loops, iterate over visible columns only.
- If page has multiple status-based tables (submitted/review/offered), all tables must consume the same `visibleColumnNames` source so behavior is identical.

### Example wiring rule
- `q-option-group v-model` should update only selectable columns.
- `allSelectable...` computed should toggle selectable set only.
- `visibleColumnNames` computed should merge always-visible + selected selectable.
- `q-table` must use `visible-columns` (not only filtered `columns`) for reliable hide/show with scoped slots.

## 9) Status Visual Pattern

Status must be consistent across list cards/table/details.

### Status chip style
- class: `costing-status-chip` or `costing-file-status-chip`
- include a small leading dot
- `text-transform: capitalize` (where needed)

```css
.costing-status-chip,
.costing-file-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
}

.status-dot,
.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
```

### Status normalization rule
Always normalize status before style mapping:
- trim
- lowercase
- fallback to `pending`

## 10) Details Page Secondary Controls

Keep conversion/cargo/profit controls inside a separate floating card below header:
- 3 numeric inputs (`dense filled soft-input`)
- right-aligned `Save` button
- use responsive columns (`col-12 col-sm-3`, etc.)

## 11) Spacing + Layout Rules

- Outer cards: `q-mb-md` / `q-mb-sm`
- Toolbar under header: `q-mb-sm`
- Control clusters: `row items-center q-gutter-sm`
- Use `no-caps` for operational buttons to keep visual consistency.

## 12) Reuse Checklist for New Pages

When creating/updating a page, verify:

1. Uses `floating-surface` + `hero-surface` cards.
2. Header typography matches list/details pattern.
3. Search/filter toolbar uses icon-toggle search and filter badge count.
4. Filters are rendered via shared `FilterSidebar` (not custom side panels).
5. Primary actions use `pill-btn slim-btn`.
6. Status chips/dots use same mapping + normalization.
7. Use layout header back navigation instead of local page back button (when layout header exists).
8. Table header tint and row/card spacing match pattern.
9. Table uses fixed-height internal scroll and shared column-selector behavior.

## 13) Suggested Shared Extraction (Optional Next Step)

To reduce duplication, consider moving these into shared UI utilities:
- shared CSS tokens for `floating-surface`, `soft-input`, `pill-btn`, `slim-btn`
- shared composable/helper for status color mapping + normalization
- shared `PageHeaderActions` component
