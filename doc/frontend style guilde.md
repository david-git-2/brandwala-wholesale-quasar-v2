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

### Dialog Glass Effect

To apply the same premium glassmorphic effect to modals and dialogs (`q-dialog`), add the `floating-surface` and shadow classes directly to the child card container (`q-card`).

**Example Template:**
```html
<q-dialog v-model="dialogOpen" persistent>
  <q-card style="width: 960px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
    <!-- Header -->
    <q-card-section class="row items-center justify-between">
      <div class="text-h6 text-weight-bold">Dialog Title</div>
      <q-btn flat round dense icon="close" v-close-popup />
    </q-card-section>
    
    <q-separator />
    
    <!-- Body Content -->
    <q-card-section>
      <!-- Forms/Inputs here -->
    </q-card-section>
  </q-card>
</q-dialog>
```

**Required CSS (Scoped or Global):**
Ensure the `.floating-surface` styles are defined in the component's `<style scoped>` block:
```css
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
```

## 3) Header Pattern

Top area should have:
- left: title + subtitle (or back button + file meta in details)
- right: primary action buttons

### Title style
- `text-h6 text-weight-bold`
- subtitle: `text-caption text-grey-8`

### Header copy rule
- Keep page headers minimal.
- Use the title only unless the page absolutely needs a short supporting label.
- Avoid descriptive subtitle text and decorative status chips in the header for settings-style pages.
- Apply the same minimal header rule to order details pages unless a supporting label is essential.

### Back navigation rule
- Do not add page-level back buttons in the page header.
- Use the shared app header back navigation as the default pattern.
- Only add local back buttons in exceptional standalone flows where the app header is unavailable.

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

### Icon-first action buttons
- Prefer icon-only outline buttons for compact admin actions and header actions.
- Use Material Symbols outline variants like `o_delete`, `o_search`, `o_edit`, `o_save`, and `o_close`.
- Prefer `flat`, `round`, and `dense` for compact icon buttons.
- Avoid button labels unless the action is not obvious from the icon alone.
- Add a `q-tooltip` for any icon-only action button.
- Invoice shortcut buttons may keep a short `Invoice` label if that improves scanability in order headers.

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

## 12) Text Color Rule

- Use black text by default for page copy, labels, and summaries.
- Prefer `text-black` or `color: #000` over gray text utilities unless a deliberate muted exception is needed.
- Keep icons and accents colored, but body text should stay black for readability and consistency across modules.
- Important amounts, totals, and emphasis text may use semantic colors such as primary, green, or red when they help scanning.
- Toolbar under header: `q-mb-sm`
- Control clusters: `row items-center q-gutter-sm`
- Use `no-caps` for operational buttons to keep visual consistency.

## 12) Inline Extra Action Button Pattern (Add New Near Field)

Use this when a selector may need new master data (for example Store / Customer Group / Brand / Category).

- Keep main input as `outlined dense`.
- Place a small helper action above the input, aligned right.
- Button style:
  - `flat dense no-caps size="xs"`
  - optional icon: `add` or `group_add`
  - compact class (example): `quick-add-btn`
- Keep label short: `Add New`.
- Behavior:
  - Route to the relevant management page (for example store manage or customer-group manage).
  - Do not place large secondary buttons in the same row as input controls.

Example layout:

```vue
<div>
  <div class="row items-center justify-between q-mb-xs">
    <div class="text-caption text-grey-8">Store</div>
    <q-btn flat dense no-caps size="xs" icon="add" label="Add New" class="quick-add-btn" />
  </div>
  <q-select outlined dense label="Store" />
</div>
```

```css
.quick-add-btn {
  min-height: 22px;
  padding: 0 4px;
}
```

## 13) Reuse Checklist for New Pages

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

## 14) Suggested Shared Extraction (Optional Next Step)

To reduce duplication, consider moving these into shared UI utilities:
- shared CSS tokens for `floating-surface`, `soft-input`, `pill-btn`, `slim-btn`
- shared composable/helper for status color mapping + normalization
- shared `PageHeaderActions` component

## 15) Responsive Mobile Card Layout (xs Screens)

For lists of items represented as cards (e.g., products, inventory items) on mobile (`xs` screens, `max-width: 599px`), transform the layout from a multi-column grid to a single-column list of horizontal rows:

- **Layout Structure**: Horizontal orientation. Place the product/item image on the left, and details/actions on the right.
- **Image Sizing**: Set the image container to exactly `1.2in` width and height (`width: 1.2in; height: 1.2in; flex: 0 0 1.2in;`).
- **Gaps & Backgrounds**: Eliminate vertical margins and gaps between the cards (`row-gap: 0px !important` on the grid parent). Cards should touch directly.
- **Card Styling**:
  - Full width (`width: 100%`).
  - Flex layout (`display: flex; flex-direction: row; align-items: center;`).
  - Zero out top/bottom margins, remove default borders/shadows, and add a subtle bottom separator border: `border-bottom: 1px solid rgba(34, 56, 101, 0.08)`.
  - Padding should be compact (e.g., `12px 8px`).
- **Right Details Area**:
  - Set `flex: 1` on the details card section.
  - Apply left padding (e.g., `padding: 0 0 0 12px !important`) to separate text from the image on the left.
- **Desktop/Full View**: Maintain the default grid layout of standard-sized vertical cards.

### Example CSS Pattern:
```css
@media (max-width: 599px) {
  .products-card-grid {
    margin: 0 !important;
    row-gap: 0px !important;
  }
  .products-card-item {
    width: 100%;
    max-width: 100%;
    flex: 0 0 100%;
    padding: 0 !important;
  }
  .product-card {
    width: 100%;
    height: auto;
    display: flex;
    flex-direction: row;
    align-items: center;
    border-radius: 0;
    border: none;
    border-bottom: 1px solid rgba(34, 56, 101, 0.08);
    background: #fff;
    padding: 12px 8px;
  }
  .product-image-wrap {
    width: 1.2in;
    height: 1.2in;
    flex: 0 0 1.2in;
    overflow: hidden;
  }
  .product-card :deep(.q-card__section) {
    flex: 1;
    padding: 0 0 0 12px !important;
  }
}
```

## 16) Responsive Table-to-Card Grid Layout (xs Screens)

For wide tables with fixed/sticky columns (e.g., costing file items, invoice items) on mobile (`xs` screens, `max-width: 599px`), convert the wide table into a responsive card layout to avoid cramped, unreadable scrolling:

### 1. Dynamic Grid Toggle
Bind the `<q-table>`'s `:grid` attribute to `$q.screen.xs` so Quasar dynamically switches between standard table mode (desktop/tablet) and grid mode (mobile).

```html
<q-table
  ...
  :grid="$q.screen.xs"
>
```

### 2. Custom Card Template (`#item` Slot)
Define the `#item` slot to override the default card rendering. Wrap the item in responsive column classes (e.g., `col-12 q-pa-xs q-sm-pa-sm`) and render a custom `<q-card>` containing:
- **Card Header**: Row checkbox, Serial Number badge (`#`), Status badge, and Edit/Delete action buttons.
- **Card Body**: Image wrapper, Product metadata, barcode details, and notes editor.
- **Costing Grid**: A structured grid showing price variables (Price GBP, Cost BDT, Offer Price BDT, Quantities) with popup editors where appropriate.

### 3. Space-saving Selects & Checkboxes
To minimize screen usage and make tables/cards more compact:
- Use `<q-checkbox dense>` for selection checkboxes (header and row-level) to reduce padding.
- Use `<q-select options-dense>` in popup editors to ensure dropdown menu lists take up less vertical space.

### 4. Spacing & Padding Adjustments
On `xs` screens, compact the overall page structure to prevent clutter:
- **Page Wrapper Spacing**: On the main `q-page`, use `q-pa-xs q-sm-pa-md` to use minimal padding on mobile devices while maintaining comfortable spacing on tablets and desktops.
- **Card Margins**: Use responsive bottom margins (e.g. `q-mb-sm q-sm-mb-md` on hero header cards, and `q-mb-xs q-sm-mb-sm` on secondary control cards) to compress the vertical layout.
- **Card Grid Container Spacing**: Use `q-pa-xs q-sm-pa-sm` on the grid cell wrapping your card to keep card grid margins tight.
