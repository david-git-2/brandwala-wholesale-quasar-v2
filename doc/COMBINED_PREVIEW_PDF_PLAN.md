# Combined Preview and PDF Feature Plan

## Goal
To merge the currently separate "Preview" and "PDF" capabilities in the Product Based Costing module into a single, cohesive workflow. This enhancement allows users to dictate precisely which data points (columns) are included in their output, and effortlessly switch between a view optimized for mobile sharing (screenshots) and a view optimized for standard printing (A4 PDF).

## Overview: Feature Flow
1. **Trigger Action:** The user opens the actions menu (`more_vert`) on the Costing File Details Page and clicks a new combined "Preview & Print" button.
2. **Column Selection:** A dialog (modal) immediately prompts the user to select which data columns they want to include (e.g., Image, Name, Offer Price, Quantity).
3. **Open Unified Layout:** Upon confirmation, a new browser tab opens the external preview route, receiving the user's column preferences.
4. **Mode Switching:** Inside the new unified preview tab, a top toolbar offers a toggle between two distinct modes:
   - **Screenshot Mode:** The current "Preview" style. A narrow, paginated list of items optimized for taking clean screenshots to share via messaging apps.
   - **PDF Mode:** The current "Print" style. A full-width, A4-sheet formatted list designed for generating clean, professional PDFs via the browser's print engine.
5. **Dynamic Data:** The table intelligently renders only the columns the user selected in step 2.
6. **Print Execution:** Clicking the "Print" action in the toolbar triggers the native browser print dialog. CSS media queries ensure the toolbar is hidden on the final output.

## Phased Implementation Breakdown

### Phase 1: Unified Preview Component Infrastructure
**What to change:** Create a new page component `ProductBasedCostingSharedPreviewPage.vue` that combines the UI elements of both existing print and preview pages. Introduce a reactive state to toggle between `screenshot` and `pdf` modes. Include a top action bar containing a `q-btn-group` for mode switching and a print button.
**Why:** Establishing the single destination page reduces code duplication and provides a seamless way for the user to evaluate both formats without needing to reload or open multiple tabs.

### Phase 2: Feature Flow Integration, Routing & Persistence
**What to change:** 
1. In `ProductBasedCostingFileDetailsPage.vue`, replace the two separate dropdown items ("Preview", "PDF") with a single "Preview & Print".
2. Create a new dialog component (e.g., `PreviewColumnSelectorDialog.vue`) that presents a checklist of available columns.
3. Use the `useMembershipColumnPreference` composable (with a key like `ui.productBasedCosting.previewPrintVisibleColumns`) to persist the user's column selections for this dialog, so their preferences are saved across sessions.
4. Update `routes/index.ts` to map the `/preview` path to our new `SharedPreviewPage` and completely remove the old `/print` route.
**Why:** The dialog puts the user in control of their data. Sending these preferences as URL query parameters ensures the new tab opens with the exact requested configuration. Persisting preferences reduces friction so the user doesn't have to re-select columns every time. Cleaning up the routing ensures a single source of truth for external viewing.

### Phase 3: Dynamic Column Rendering
**What to change:** Update the table logic in `ProductBasedCostingSharedPreviewPage.vue` to read the columns specified in the URL query string. Dynamically construct the `QTableColumn` array and use `v-if` logic within the `template #body` slots to only show requested fields.
**Why:** The unified page must respect the user's selections from the dialog. Hardcoding columns defeats the purpose of the feature. This step ensures flexibility and customization.

### Phase 4: CSS Refinement & Cleanup
**What to change:** Consolidate the CSS styles from the previous two separate components into the unified page. Ensure `@media print` rules perfectly isolate the content, hiding the action bars and applying A4 styling only when appropriate. Delete `ProductBasedCostingPreviewPage.vue` and `ProductBasedCostingFilePrintPage.vue`.
**Why:** Finalizing the presentation ensures a premium look and feel. Deleting the old components removes tech debt and prevents confusion for future maintainers.
