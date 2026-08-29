# Standard Ops Spreadsheet & Table View Pattern

This document serves as the canonical reference specification and template blueprint for creating dense, high-performance, Excel-like table views with sticky headers, custom bottom tabs/scrollbars, and inline click-to-edit fields across Brandwala.

---

## 1. Page Architecture & Fixed Layout

Every table view must lock vertical outer scrolling to the browser viewport, delegating scroll to internal table layers:

```html
<template>
  <!-- Fixed full-height container -->
  <q-page class="column no-wrap bg-grey-1" style="height: calc(100vh - 55px); overflow: hidden">
    
    <!-- 1. Top Static / Sticky Header & Action Toolbar -->
    <div class="bg-white border-bottom q-px-md q-py-sm shrink-0">
      <!-- Reactive document title, status badge, selection batch actions, column toggle & settings -->
    </div>

    <!-- 2. Middle Scrollable Markup Table -->
    <div
      ref="tableScrollContainerRef"
      class="col overflow-auto q-pa-none bg-white hide-native-scrollbar"
      style="overflow-x: auto; overflow-y: auto"
      @scroll="onTableScroll"
    >
      <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 1080px; width: 100%">
        <thead>...</thead>
        <tbody>...</tbody>
      </q-markup-table>
    </div>

    <!-- 3. Bottom Static / Sticky Excel Navigation & Synchronous Scrollbar Bar -->
    <ShipmentExcelBottomBar
      :sheets="sheets"
      :active-sheet-id="activeSheetId"
      :scroll-thumb-width="scrollThumbWidth"
      :scroll-thumb-left="scrollThumbLeft"
      ...
    />
  </q-page>
</template>
```

---

## 2. Table Column Dimensions & Alignment Standard

| Column Role | Header Width (`th`) | Body Cell Width (`td`) | Input Width (`q-input`) | Alignment & Styling |
| :--- | :---: | :---: | :---: | :--- |
| **Selection Checkbox** | `18px` (`q-pa-none`) | `18px` (`q-pa-none`) | — | `text-center`, `size="xs"` checkbox |
| **SL / Sequence** | `36px` (`q-pa-none`) | `36px` (`q-pa-none`) | `max-width: 32px` | `text-center`, borderless in-place editable |
| **Image Thumbnail** | `82px` | `82px` | — | `0.85in × 0.85in` square avatar with soft radius |
| **Product Name** | `120px` | `120px` (`max-width: 120px`) | — | Left-aligned, multi-line wrap (`word-break: break-word`) |
| **Product Codes** | `115px` | `115px` | — | Left-aligned, monospace, 1-click copy buttons |
| **Purchase Price** | `56px` | `56px` | `max-width: 50px` | `text-center`, soft mint tint (`#daf3e4`), unit + total |
| **Landed Cost** | `56px` | `56px` | — | `text-center`, soft peach tint (`#ffe8d1`), no currency symbol |
| **Ordered Qty** | `56px` | `56px` | `max-width: 50px` | `text-center`, soft blue tint (`#d0e6ff`), integer input |
| **Product Weight** | `56px` | `56px` | `max-width: 50px` | `text-center`, 2-line header, 3 decimals |
| **Package Weight** | `56px` | `56px` | `max-width: 50px` | `text-center`, soft purple tint (`#e8d7f7`), 3 decimals |

---

## 3. Excel-Style Borderless Inline Editable Fields

### Markup Pattern:
```html
<q-input
  :model-value="getDraftValue(item, 'ordered_quantity')"
  type="number"
  min="1"
  step="1"
  dense
  outlined
  hide-bottom-space
  class="inline-edit-input excel-cell-input"
  style="max-width: 58px"
  input-class="text-center text-weight-bold"
  @update:model-value="(val) => setDraftValue(item, 'ordered_quantity', val)"
  @blur="saveDraftValue(item, 'ordered_quantity')"
  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
/>
```

### Essential CSS Rules:
```css
/* Compact 28px cell height */
:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

/* Hide default browser numeric spin arrows */
:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

/* Borderless transparent idle state: inherits cell background tint */
:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

/* Crisp Excel focus box */
:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}
```

---

## 4. Soft Column Tints (Color Code Standard)

```css
/* Price Column (Mint Green) */
.shipment-items-markup-table th.bw-ops-col-tint--price,
.shipment-items-markup-table td.bw-ops-col-tint--price {
  background-color: #daf3e4 !important;
  box-shadow: inset 2px 0 0 #059669;
}

/* Cost Column (Warm Peach) */
.shipment-items-markup-table th.bw-ops-col-tint--cost,
.shipment-items-markup-table td.bw-ops-col-tint--cost {
  background-color: #ffe8d1 !important;
  box-shadow: inset 2px 0 0 #ea580c;
}

/* Qty Column (Soft Blue) */
.shipment-items-markup-table th.bw-ops-col-tint--qty,
.shipment-items-markup-table td.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

/* Weight Column (Soft Purple) */
.shipment-items-markup-table th.bw-ops-col-tint--weight,
.shipment-items-markup-table td.bw-ops-col-tint--weight {
  background-color: #e8d7f7 !important;
  box-shadow: inset 2px 0 0 #9333ea;
}
```

---

## 5. Modularized Component Architecture

To prevent pages from exceeding manageable sizes, breakout elements into dedicated components:

1. **`ShipmentExcelBottomBar.vue`**: Bottom navigation tab sheets, add sheet button, right track horizontal scrollbar with drag thumb.
2. **`ShipmentSettingsDrawer.vue`**: Slide-out drawer with tabbed sections (*Details*, *Summary*, *Rates*, *Status*).
3. **`ShipmentSectionSheetDialog.vue`**: Add / Edit section & invoice dialog with Quasar date picker.
4. **`ShipmentSectionViewDialog.vue`**: Read-only summary card modal for sections/sheets.
5. **`AddCustomColumnDialog.vue`**: User-defined custom column adder with type selector.
