# Thrift Sales + Reports — UX friction fix

**How to run:** Tell the agent: `Implement Phase N from doc/v2/thrift/ux-friction-fix.md only.`

**Agent law:** Read **only that phase section**. Implement exactly as written. Do not research, do not ask questions, do not open other thrift docs, do not invent alternate UX. If something is missing from the phase text, follow **Ambiguity defaults** at the bottom of this file.

**Global DO NOT (every phase):** change RPC contracts · change RTO/return/PnL rules · touch stock/inbound · `backend:types` · edit files outside that phase’s CHANGE list.

---

## Progress

- [x] Phase 1
- [x] Phase 2
- [x] Phase 3
- [x] Phase 4
- [x] Phase 5
- [x] Phase 6
- [x] Phase 7
- [x] Phase 8
- [x] Phase 9

Order: `1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9`

---

## Phase 1 — Invoice details: situation menu + one primary CTA

### CHANGE (only)
`web/src/modules/thrift/sales/pages/ThriftSalesInvoiceDetailsPage.vue`

### Do not open
Create page, sales list, reports, workflow.md, tracks component (phase 2).

### Keep using (do not rewrite bodies)
- `canShowRemittance`, `canShowMarkRto`, `canShowReturnItems`, `canStaffMistake`, `canRecordRemittance`
- `openRemittanceDialog()`, `openRtoDialog()`, `openReturnDialog()`, `confirmRevert('STAFF_MISTAKE')`

### UI — header actions (replace current peer buttons)

Keep: Back, title, badges, `LearnMoreHelpBtn`, **Print** (outline).

Remove from header the peer buttons: Record COD, Return items, Mark RTO, Staff Mistake.

Add:

1. **Primary** (unelevated, primary color) — show only when `canRecordRemittance && canShowRemittance`:
   - `label="Record COD"`
   - `@click="openRemittanceDialog()"`
   - same `:disable` as today (`reverting || remitting || updatingDelivery || returning`)

2. **What happened?** — `q-btn-dropdown` outline `color="grey-8"` `no-caps` `label="What happened?"`  
   Show the dropdown **only if** at least one menu item below is visible.  
   Menu items (exact labels), each `v-if` gated:

   | Menu label | `v-if` | Action |
   | :--- | :--- | :--- |
   | `Courier brought COD cash` | `canRecordRemittance && canShowRemittance` | `openRemittanceDialog()` |
   | `Customer did not take the parcel` | `canShowMarkRto` | `openRtoDialog()` |
   | `Customer returned items after delivery` | `canShowReturnItems` | `openReturnDialog()` |
   | `Wrong sale entered (staff mistake)` | `canStaffMistake && invoice.status === 'ACTIVE' && !hasReturns` | `confirmRevert('STAFF_MISTAKE')` |

### UI — remove duplicate CTAs in page body

Delete the action buttons block in the money/COD card that currently renders:
- `Record COD remittance`
- `Return items`
- `Mark RTO (no pickup)`
and the caption `COD = cash from courier…` next to them.

Keep the **Returns** card button `Return items` that calls `openReturnDialog()` (single secondary entry is OK).

### Labels on this page only

Replace `labelize(...)` display for payment/delivery/invoice status badges with these maps (local helpers in this file):

```ts
const PAYMENT_LABELS: Record<string, string> = {
  COD_PENDING: 'Waiting for COD',
  PAID: 'Paid',
  PARTIALLY_REFUNDED: 'Partially refunded',
  REFUNDED: 'Refunded',
  WRITTEN_OFF: 'Written off',
};
const DELIVERY_LABELS: Record<string, string> = {
  PENDING: 'Pending',
  READY: 'Ready',
  IN_TRANSIT: 'In transit',
  DELIVERED: 'Delivered',
  RETURNED: 'Came back',
};
const INVOICE_STATUS_LABELS: Record<string, string> = {
  ACTIVE: 'Active',
  PARTIALLY_RETURNED: 'Partially returned',
  RETURNED: 'Closed — returned',
};
```

Fallback: existing `labelize`. Do not change stored enum values.

### Done checklist
- [x] Header never shows more than one unelevated money CTA (Record COD)
- [x] RTO / Return / Staff Mistake only via What happened?
- [x] Money-card duplicate COD/RTO/Return buttons removed
- [x] Existing dialogs still open unchanged
- [x] No other files changed

---

## Phase 2 — Status tracks: delivery clickable, payment display-only

### CHANGE (only)
`web/src/modules/thrift/sales/components/ThriftSalesInvoiceStatusTracks.vue`

### Do not open
Details page (phase 1 already owns CTAs). Do not change emit types used by parent beyond making payment non-interactive.

### Behavior (locked)
1. **Delivery** row: keep current click → `emit('select-delivery', …)` and `deliveryBtnDisabled` logic unchanged.
2. **Payment** row: display only.
   - `paymentBtnDisabled` → always `return true` for every status (including when current).
   - `writtenOffDisabled` → always `true`.
   - `onPaymentClick` → no-op (`return` immediately).
3. Plain labels in `formatStatusLabel`:

```ts
const labels: Record<string, string> = {
  PENDING: 'Pending',
  READY: 'Ready',
  IN_TRANSIT: 'In transit',
  DELIVERED: 'Delivered',
  RETURNED: 'Came back',
  COD_PENDING: 'Waiting for COD',
  PAID: 'Paid',
  WRITTEN_OFF: 'Written off',
  REFUNDED: 'Refunded',
  PARTIALLY_REFUNDED: 'Partially refunded',
};
```

### Done checklist
- [x] Clicking PAID / Written off does nothing
- [x] Delivery advance still emits when allowed
- [x] Only this file changed

---

## Phase 3 — Sales list desk

### CHANGE (only)
`web/src/modules/thrift/sales/pages/ThriftSalesPage.vue`

### API fact (do not fight it)
`ListSalesInvoicesParams` supports only: `search`, `paymentStatus`, `status`, `deliveryStatus`.  
**Do not** add date/channel filters. **Do not** change repository/RPC.

### Presets (chips above filters)

`v-model="listPreset"` type:

```ts
type ListPreset = 'active' | 'cod' | 'ready' | 'transit' | 'all';
```

Default: `'active'` (matches today’s `statusFilter = 'ACTIVE'`).

| Chip label | Sets |
| :--- | :--- |
| `Active` | `status=ACTIVE`, payment=`null`, delivery=`null` |
| `COD waiting` | `status=ACTIVE`, payment=`COD_PENDING`, delivery=`null` |
| `Ready` | `status=ACTIVE`, payment=`null`, delivery=`READY` |
| `In transit` | `status=ACTIVE`, payment=`null`, delivery=`IN_TRANSIT` |
| `All` | status=`null`, payment=`null`, delivery=`null` |

Implementation: when preset changes, assign the three filter refs then reset `page=1`.  
When user manually changes a `q-select` filter, set `listPreset` to a sentinel or clear highlight (use `listPreset = 'custom'` internally; do not show Custom chip).

Keep the three `q-select` filters; place chips in a row above them.

### Query hydrate (for phase 5)
On setup, if `route.query.paymentStatus === 'COD_PENDING'`:
- set preset to `cod` (apply COD waiting filter row)
- do not ask user

### Empty state (replace `#no-data` copy)

Active preset alone is **not** a “filtered” empty (so brand-new shops still see Create).

```ts
const filtersActive = computed(() => {
  if (search.value.trim()) return true;
  if (listPreset.value !== 'active') return true;
  if (paymentStatusFilter.value) return true;
  if (deliveryStatusFilter.value) return true;
  if (statusFilter.value !== 'ACTIVE') return true;
  return false;
});
```

If `filtersActive`:
- title: `No matching invoices`
- body: `Try another filter or clear search.`
- button: `Clear filters` → preset `active`, search `''`, page `1`

Else:
- title: `No invoices yet`
- body: `Create a counter sale to see it listed here.`
- Create Invoice button (unchanged `v-if="canCreate"`)

### Row status sentence

Remove table columns: `paymentMethod`, `paymentStatus`, `deliveryStatus`, `status`.  
Add column `statusSummary` label `Status`.

```ts
function statusSentence(row: ThriftSalesInvoiceListItem): string {
  const ch = row.saleChannel === 'ONLINE' ? 'Online' : 'In-store';
  const payMap: Record<string, string> = {
    COD_PENDING: 'Waiting for COD',
    PAID: 'Paid',
    PARTIALLY_REFUNDED: 'Partially refunded',
    REFUNDED: 'Refunded',
    WRITTEN_OFF: 'Written off',
  };
  const delMap: Record<string, string> = {
    PENDING: 'Pending',
    READY: 'Ready',
    IN_TRANSIT: 'In transit',
    DELIVERED: 'Delivered',
    RETURNED: 'Came back',
  };
  const pay = payMap[row.paymentStatus] || row.paymentStatus;
  if (row.deliveryStatus) {
    const del = delMap[row.deliveryStatus] || row.deliveryStatus;
    return `${ch} · ${del} · ${pay}`;
  }
  return `${ch} · ${pay}`;
}
```

Keep Channel column badge as-is.

### Header link
Add flat button next to Create: `label="Returns"` `:to="\`/${tenantSlug}/app/thrift/sales/returns\`"`.

### Done checklist
- [x] Five presets set filters as table above
- [x] `?paymentStatus=COD_PENDING` opens COD waiting
- [x] Filtered empty ≠ “No invoices yet”
- [x] Status sentence column live; four old status columns gone
- [x] Only this file changed

---

## Phase 4 — Create sale safety

### CHANGE (only)
`web/src/modules/thrift/sales/pages/ThriftCreateSalesInvoicePage.vue`

### Labels (exact)
Replace every user-visible `Generate`:
- Offline (`!isOnline`): `Complete sale`
- Online: `Create order`

Under sticky primary (online review + offline), add caption:
- Offline: `Marks this sale paid now.`
- Online: `Creates a COD order. Not counted as earned until delivered.`

### Step chips — lock forward jumps

Replace `goOnlineStep` usage for chips:

```ts
function onOnlineStepChipClick(step: number) {
  if (step <= onlineStep.value) {
    onlineStep.value = step;
    return;
  }
  // only allow moving forward one validated step at a time
  if (step === onlineStep.value + 1) {
    goNextOnlineStep();
    return;
  }
  // trying to skip: walk forward with validation
  const walk = async () => {
    while (onlineStep.value < step) {
      const before = onlineStep.value;
      goNextOnlineStep();
      if (onlineStep.value === before) return; // validation failed
    }
  };
  void walk();
}
```

Wire chips to `onOnlineStepChipClick` not raw `goOnlineStep`.

### Disabled primary reason

When `generateDisabled`:
- If `selectedItems.length === 0`: caption `Add at least one item.`
- Else if online && `onlineStep !== 3`: caption `Finish all steps to create the order.`
- Else: no caption

Show caption under header primary and sticky primary.

### Channel switch confirm

When `invoiceForm.saleChannel` changes via the toggle, if `selectedItems.length > 0` OR any of customerName/phone/address filled:

```ts
await requestConfirmation({
  title: 'Switch channel?',
  message: 'Switching Offline/Online keeps items but online-only courier fields may not apply.',
  // use whatever requestConfirmation signature this file already uses
});
```

If user cancels, revert `saleChannel` to previous value.  
Use a `watch` with old/new; skip while `draftHydrating`.

### Fee presets (online courier step only)

Above the three fee rows, add `q-select` `v-model="feePreset"` options:

| label | value | Sets |
| :--- | :--- | :--- |
| Customer pays delivery + COD · Shop pays packing | `typical` | courier=`CUSTOMER`, cod=`CUSTOMER`, packing=`SHOP` |
| Shop pays all fees | `shop` | all `SHOP` |
| Customer pays all fees | `customer` | all `CUSTOMER` |
| Custom | `custom` | no auto change |

On select of non-`custom`, assign the three `*PaidBy` fields.  
If user manually changes a payer, set `feePreset = 'custom'`.  
Default when entering online courier step: `typical` applied once if all payers empty/null.

### Done checklist
- [x] No user-visible “Generate”
- [x] Chip cannot skip to Review with empty required customer fields
- [x] Disable reason caption visible when disabled
- [x] Channel confirm when cart/customer dirty
- [x] Fee preset applies payers
- [x] Only this file changed

---

## Phase 5 — COD report → sales deeplink

### CHANGE (only these two)
1. `web/src/modules/thrift/reports/pages/ThriftCodReportPage.vue`
2. `web/src/modules/thrift/sales/pages/ThriftSalesPage.vue` — **only if** phase 3 hydrate missing; if phase 3 already hydrates `paymentStatus`, touch COD page only

### COD page UI
Below hero / support grid, add:

```vue
<q-btn
  color="primary"
  unelevated
  no-caps
  class="full-width"
  icon="ph ph-arrow-right"
  label="Open COD waiting invoices"
  :to="`/${tenantSlug || 'tenant'}/app/thrift/sales?paymentStatus=COD_PENDING`"
/>
```

Use existing `tenantSlug` from auth store (add `storeToRefs` if needed).

### Done checklist
- [x] Button routes to sales with query
- [x] Sales list shows COD waiting filter (phase 3 hydrate)
- [x] No new RPC

---

## Phase 6 — Reports hub copy

### CHANGE (only)
`web/src/modules/thrift/reports/pages/ThriftReportsPage.vue`

### Exact copy edits
1. Under the COD waiting metric (`glance-card__meta` for COD), change meta text from `COD waiting` to two lines:
   - value label stays number
   - meta: `COD waiting`
   - add under grid a single line: `Waiting is not earned yet.` class `text-caption text-grey-7`

2. Ledger button: change `label="Money in/out history"` → `label="Cash journal (not profit)"`

### Done checklist
- [x] Both copy changes present
- [x] No API / routing changes beyond label
- [x] Only this file changed

---

## Phase 7 — Shipment list profit teaser

### CHANGE (only)
`web/src/modules/thrift/reports/pages/ThriftShipmentReportsListPage.vue`

### Behavior (locked — no migration)
For each id in `filteredRows`, load teaser via existing repository method:

`thriftReportsRepository.getShipmentSalesReport(tenantId, id)`

Use TanStack `useQueries` (already used elsewhere in app) or a simple per-row query composable pattern already in `useThriftReportsQuery.ts` — **prefer extending** `useThriftReportsQuery.ts` with:

```ts
export function useThriftShipmentReportQuery(tenantId, shipmentId) { ... existing getShipmentSalesReport ... }
```

only if a single-shipment query helper does not already exist. If adding helper: also allowed to edit  
`web/src/modules/thrift/reports/composables/useThriftReportsQuery.ts`.

On each row, under the date meta, show:
- If loading: `…`
- If error: `Profit unavailable`
- Else if `summary.unitsSold + summary.unitsRto + summary.unitsReturned === 0`: `No finished sales yet`
- Else: `Profit {formatThriftAmount(summary.netProfit)} · {unitsSold} delivered`

Import `formatThriftAmount` from `src/modules/thrift/currency/utils/formatMoney`.

Limit concurrency naturally via vue-query; do not build a new RPC.

### Done checklist
- [x] Each shipment row shows profit or empty/error line
- [x] Uses `getShipmentSalesReport` only
- [x] Files touched ⊆ list page + optional query composable

---

## Phase 8 — Earn report → sales period deeplink

### CHANGE (only)
`web/src/modules/thrift/reports/pages/ThriftSalesReportPage.vue`  
and hydrate in `ThriftSalesPage.vue` for `dateFrom`/`dateTo` **only if you also extend list API**.

### Locked approach (no new report RPC)
List RPC has **no date filter today**. Do **not** add migration in this phase.

Ship this only:
1. On earn page, under hero, button:
   - `label="Open sales list"`
   - `:to="\`/${tenantSlug}/app/thrift/sales\`"`
2. Caption: `Sales list has no date filter yet — use search or COD/Ready presets.`

### Done checklist
- [x] Button to sales list exists
- [x] No migration
- [x] No fake date filtering

---

## Phase 9 — Returns empty honesty

### CHANGE (only)
`web/src/modules/thrift/sales/pages/ThriftSalesReturnsPage.vue`

### Empty `#no-data`
If `search.trim() || dateFrom || dateTo || damagedFilter !== null`:
- `No matching returns`
- `Clear filters` resets search `''`, dateFrom=startOfMonth, dateTo=today, damagedFilter=`null`, page=`1`

Else:
- `No returns yet`
- `Create from an invoice → Return items.`

### Done checklist
- [x] Two empty states
- [x] Only this file changed

---

## Ambiguity defaults (if anything still unclear)

1. Prefer **smallest diff** that satisfies Done checklist.
2. Reuse Quasar patterns already in the same file (`q-btn`, `q-btn-dropdown`, `requestConfirmation`).
3. Do not rename routes or RPC names.
4. Do not add README.
5. Do not run full test suite; no typecheck whole repo.
6. If `requestConfirmation` signature differs, match the nearest existing call in the **same file**.
7. If a phase’s prerequisite phase is unchecked, still implement this phase’s CHANGE files only; do not implement other phases.
