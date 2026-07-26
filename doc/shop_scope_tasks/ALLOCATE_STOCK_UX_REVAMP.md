# Allocate Stock Page UX & Usability Revamp

## 1. Problem Statement
The current `AllocateStockPage.vue` is heavily focused on micro-interactions, making it tedious and inefficient for bulk or high-volume operations. Specifically:
- Users must expand individual product rows to view child tenant allocations.
- Users must click "Save" for *each individual child tenant* after entering a quantity.
- There is no workflow to allocate an entire shipment (or bulk products) to a single tenant at once.
- The UI feels slow and difficult to operate for warehouses processing large shipments with many SKUs.

## 2. Proposed UX & Workflow Changes

### A. Introduce "Bulk Allocate Shipment" Feature
**Product Value:** Saves massive amounts of time when a parent company decides an entire incoming shipment is destined for a specific sister concern (child tenant).
**UX Implementation:**
- Add a top-level action button: **"Bulk Allocate Shipment"**.
- This opens a dialog or wizard where the user selects:
  1. A Shipment Batch (from ready stock).
  2. A Target Child Tenant.
  3. Action: "Allocate all unallocated stock to this tenant".
- This turns hundreds of clicks into a 3-click process.

### B. Shift to a "Batch Save" Model vs. "Individual Save"
**Product Value:** Data entry should feel fluid like Excel, not like filling out 100 separate forms.
**UX Implementation:**
- Remove the individual "Save" buttons next to each child tenant input.
- Allow the user to modify draft quantities freely across multiple expanded rows or within a single expanded row.
- Introduce a **"Save Allocations"** button at the bottom of the expanded row (or globally at the page level) that submits all changed quantities in a single payload or batched requests.
- Add visual indicators (e.g., a yellow background or a "modified" dot) to inputs that have unsaved changes.

### C. Matrix / Grid View Toggle (Optional but Recommended)
**Product Value:** If the parent tenant only has a few sister concerns (e.g., 2-4 child tenants), an expandable list is unnecessary friction.
**UX Implementation:**
- Add a toggle: **"List View"** vs **"Grid View"**.
- In Grid View, turn Child Tenants into dynamic columns. 
- Rows = Products. Columns = Child Tenant 1 Qty, Child Tenant 2 Qty.
- Users can simply tab through the grid and type quantities rapidly without expanding anything.

### D. Better Visual Indicators for Allocation Status
**Product Value:** Users need at-a-glance understanding of what needs their attention.
**UX Implementation:**
- Instead of just text columns for "Pool Qty", "Allocated", and "Unallocated", use a visual **Progress Bar** for each product.
- **Color Coding:**
  - `Green`: 100% Allocated.
  - `Yellow`/`Orange`: Partially Allocated (stock remaining).
  - `Red`/`Grey`: 0% Allocated.
- Add quick filters: "Show Unallocated Only", "Show Fully Allocated".

### E. "Quick Fill" Actions
**Product Value:** Speeds up common allocation math.
**UX Implementation:**
- Inside the expanded row for a product, add quick action buttons next to a child tenant:
  - **"Max"**: Instantly assigns all remaining unallocated pool quantity to this tenant.
  - **"Split Evenly"**: Evenly divides remaining pool quantity across all listed child tenants.

## 3. Phased Implementation Plan

### Phase 1: Bulk Allocate Shipment & Quick Actions
**Goal**: Allow users to allocate an entire shipment to a specific child tenant instantly, and provide quick fill actions to assign maximum stock without manual data entry.
**Files to Change**:
- `web/src/modules/procurement_stock/pages/AllocateStockPage.vue`
- `web/src/modules/procurement_stock/stores/globalStockAllocationStore.ts`
- `web/src/modules/procurement_stock/repositories/globalStockAllocationRepository.ts`
**Details**:
1. Add a **"Bulk Allocate Shipment"** button at the top toolbar that opens a dialog to select a shipment and target child tenant, triggering a bulk allocation operation.
2. Inside the expanded table row, add a **"Max"** button next to the child tenant's quantity input to instantly fill it with the remaining unallocated pool quantity.
3. Add visual Progress Bars in the table for stock allocation status (Green: 100%, Yellow: Partial, Red: 0%) to replace text-only capacity limits.

### Phase 2: Flow Optimization & Batch Saving
**Goal**: Remove repetitive clicking by shifting from individual saves to a per-row or global batch save system, improving the data entry flow.
**Files to Change**:
- `web/src/modules/procurement_stock/pages/AllocateStockPage.vue`
**Details**:
1. Remove the individual "Save" buttons next to each child tenant input.
2. Implement a **"Save All"** button per expanded product row (or a sticky one for the page) that handles saving all edited quantities in one go.
3. Enhance keyboard accessibility so users can quickly tab through the child tenant quantity inputs without mouse interaction.
4. Add quick filter Chips above the table (e.g., "Unallocated", "Partially Allocated") for easier navigation.

### Phase 3: Advanced UX - Grid View Toggle
**Goal**: Eliminate the need to expand rows entirely for parent tenants with a small number of sister concerns.
**Files to Change**:
- `web/src/modules/procurement_stock/pages/AllocateStockPage.vue`
**Details**:
1. Add a toggle switch: **"List View"** vs **"Grid View"**.
2. In Grid View, dynamically render Child Tenants as columns in the main `q-table`.
3. Provide editable cells inside the table for each child tenant column to allow rapid, Excel-style data entry across all products simultaneously.
4. Implement a global "Save Changes" mechanism to commit the entire page's grid state.

---
*Prepared by UX / Product Management*
