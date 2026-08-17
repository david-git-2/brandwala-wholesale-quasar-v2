# Shipment Engine — Cost, Balance & Costing

> Reusable, pure-function computation layer for all shipment types.
> Consumes `shipment_cost_entries` + `shipment_items` + header `total_weight_kg` (+ boxes only for verification display).
>
> **Dual-phase design**: UI computes for live preview; server computes for authoritative **stamping** on `shipment_items.landed_cost_bdt`.
>
> **Cost ownership:** [schema.md](./schema.md) §4 — stamp on shipment item; stock has no cost; invoice snapshots provisional; reports join current stamp for actual P&L.
>
> **Schema canon:** [schema.md](./schema.md) — day-one = one `product` + one `cargo` entry; weight rules in §2.

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         shipment_engine/                              │
│                                                                      │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────┐  ┌────────────┐ │
│  │ costEngine.ts │  │weightBalance  │  │ price    │  │ costRevision│ │
│  │               │  │  .ts          │  │ Balance  │  │  .ts (opt) │ │
│  │ • effective   │  │ • estimated   │  │  .ts     │  │ • old→new  │ │
│  │   rates       │  │   vs actual   │  │ • est vs │  │   delta    │ │
│  │ • breakdown   │  │   weight      │  │   invoice│  │ • UI /      │ │
│  │ • per-item    │  │ • pkg weight  │  │ • price  │  │   wallet    │ │
│  │   landed cost │  │   adjustments │  │   adjust │  │   stub only │ │
│  │ • summary     │  │ • remainder   │  │ • rest   │  │             │ │
│  └───────────────┘  └───────────────┘  └──────────┘  └────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                         types.ts                               │  │
│  │  Shared input/output interfaces for all engines                │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
         ▲ Pure functions — no DB, no store, no side effects
         │
         │ Consumed by
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│  UI (live preview)       │  Server RPCs            │  Tests         │
│  • Computed costs        │  • Finalize: stamp      │  • Unit tests  │
│  • Balance previews      │    landed_cost_bdt      │    with plain  │
│  • No network cost       │  • Revision: re-stamp   │    objects     │
│  • For UX only           │  • Authoritative        │                │
└──────────────────────────────────────────────────────────────────────┘
```

**Keep `costEngine`.** Drop treating a variance ledger as P&L authority — true profit is report-side join to the stamp ([schema.md](./schema.md) §4).

**Key Principle**: Every function in the engine is **pure** — takes plain objects as input, returns plain objects as output. No Supabase client, no Pinia store, no Vue reactivity inside.

---

## 2. File Location

```
web/src/shared/shipment-engine/
├── types.ts              # Shared input/output interfaces
├── costEngine.ts         # Effective rates, cost breakdown, landed cost (required)
├── costRevision.ts       # Optional: old→new delta helper for revision UI / wallet stub
├── weightBalance.ts      # Weight delta calculation & package weight distribution
├── priceBalance.ts       # Price delta calculation & purchase price distribution
└── __tests__/
    ├── costEngine.test.ts
    ├── costRevision.test.ts
    ├── weightBalance.test.ts
    └── priceBalance.test.ts
```

> Rename from older sketch `costVariance.ts` if present — same helper, clearer job (not “accounting variance table”).

> Located in `web/src/shared/shipment-engine/` — import via `src/shared/shipment-engine` (no procurement module coupling). Day-one live preview uses `costEngine.ts` + `types.ts`; optional `costRevision.ts` for UI stamp deltas. Weight/price balance helpers remain module-local until a later extract.

---

## 3. Shared Interfaces (`types.ts`)

### 3.1 Inputs

```typescript
/** A single cost/rate entry from shipment_cost_entries */
export interface CostEntry {
  cost_type: string;        // day-one: 'product' | 'cargo'; stubs: 'duty' | 'insurance' | 'labor' | ...
  entity_type?: string;     // stub — payee ('vendor' | cargo…); never 'shipment'
  entity_id?: number;       // stub — payee id; settlement intent only (no auto wallet post day one)
  currency_id: number | null;
  amount: number;           // total in source currency (not per-kg)
  exchange_rate: number;    // to base currency (BDT). 1.00 for local
  payment_source?: string;  // stub: 'cash' | 'credit' | 'wallet' | omit = costing only
  allocation?: string;      // stub: 'by_weight' | 'by_value' | 'by_qty' | 'per_unit'
}

/** A shipment line item */
export interface LineItem {
  id: number;
  name: string;
  quantity: number;
  unit_purchase_price: number;  // in purchase currency
  product_weight_gm: number;
  package_weight_gm: number;
}

/** A physical box */
export interface Box {
  weight_kg: number;
}

/** Minimal shipment header context needed by the engine */
export interface ShipmentContext {
  shipment_type: string;        // 'international' | 'local' | 'thrift' | 'transfer'
  total_weight_kg: number | null;  // cargo invoice weight (live received_weight) — NOT Σ boxes
}
```

### 3.2 Outputs

```typescript
/** Effective rates derived from cost entries */
export interface EffectiveRates {
  product_rate: number;         // weighted avg exchange rate for 'product' entries
  cargo_rate: number;           // weighted avg exchange rate for 'cargo' entries
  blended_rate: number | null;  // combined transaction rate (international only)
  rates_by_type: Record<string, number>;  // effective rate per cost_type
}

/** Full cost breakdown */
export interface CostBreakdown {
  total_quantity: number;
  total_weight_kg: number;           // estimated from items
  cargo_weight_kg: number;           // invoice weight or fallback to estimated
  costs_by_type: Record<string, {    // keyed by cost_type
    purchase_total: number;          // Σ(amount) in source currency
    base_total: number;              // Σ(amount × exchange_rate) in BDT
    effective_rate: number;          // weighted avg rate
  }>;
  grand_total_purchase: number;      // all cost types summed (purchase currency)
  grand_total_base: number;          // all cost types summed (BDT)
}

/** Per-item landed cost result */
export interface ItemLandedCost {
  item_id: number;
  purchase_base: number;             // unit price + allocated cargo share (purchase currency)
  landed_cost_bdt: number;           // final unit cost in BDT
  cargo_share_purchase: number;      // cargo allocated to this item (purchase currency)
  total_line_cost_bdt: number;       // landed_cost_bdt × quantity
}

/** Complete shipment cost summary */
export interface ShipmentCostSummary {
  effective_rates: EffectiveRates;
  breakdown: CostBreakdown;
  item_costs: ItemLandedCost[];
  grand_total_bdt: number;           // Σ of all item total_line_cost_bdt
}
```

---

## 4. Cost Engine (`costEngine.ts`)

### 4.1 `computeEffectiveRates(entries: CostEntry[]): EffectiveRates`

Computes weighted average exchange rate per `cost_type`:

```
effective_rate(type) = Σ(amount × exchange_rate) / Σ(amount)
                       where cost_type = type
```

For `blended_rate` (international only): money-weighted blend of product + cargo (live `transaction_rate` parity):

```
blended = (goods_bdt + cargo_bdt) / (Σ product.amount + Σ cargo.amount)
```

### 4.2 `computeCostBreakdown(entries: CostEntry[], items: LineItem[], ctx: ShipmentContext): CostBreakdown`

Aggregates all cost entries into a structured breakdown:
- Groups by `cost_type`
- Computes `purchase_total` and `base_total` per group
- Determines `cargo_weight_kg` from **header invoice weight** (see §5) — never from boxes

### 4.3 `computeItemLandedCost(item: LineItem, entries: CostEntry[], items: LineItem[], ctx: ShipmentContext): ItemLandedCost`

Per-item landed cost (**day-one parity** with live `landedCost.ts`):

1. **Cargo allocation** — distributes `Σ(cargo.amount)` proportional to gross weight share:
   ```
   item_gross_kg = ((product_weight_gm + package_weight_gm) × quantity) / 1000
   cargo_share   = (item_gross_kg / estimated_pack_kg) × Σ(cargo.amount)
   ```
   Falls back to qty share when no weight basis.

2. **Purchase base** = `unit_purchase_price + (cargo_share / quantity)`

3. **Landed cost BDT**:
   - **Local**: `purchase_base` (rate = 1.00)
   - **International**: `purchase_base × blended_rate`

**Later stub:** extra `cost_type`s allocate by entry `allocation` into BDT on the line (prefer Σ components over stretching blended FX).

### 4.4 `computeShipmentCostSummary(entries: CostEntry[], items: LineItem[], ctx: ShipmentContext): ShipmentCostSummary`

Top-level aggregation: effective rates, breakdown, per-item landed costs, grand total BDT.

---

## 5. Weight (`weightBalance.ts` + costing basis)

Canon: [schema.md](./schema.md) §2.

### 5.0 Cargo weight for costing (not boxes)

```
estimated_pack_kg = Σ((product_weight_gm + package_weight_gm) × quantity) / 1000

cargo_kg = ctx.total_weight_kg   if set and > 0
         else estimated_pack_kg
```

| Source | Role |
| :--- | :--- |
| `ctx.total_weight_kg` | Cargo **invoice** weight — costing + balance target |
| Line weights | Estimate + share basis after apply |
| `shipment_boxes` | Verification / display only — **never** `cargo_kg` |

UI may set cargo entry `amount = cargo_kg × per_kg_rate`; engine uses entry `amount`, not a header `cargo_rate`.

### 5.1 `computeEstimatedWeightKg(items: LineItem[]): number`

```
Σ((product_weight_gm + package_weight_gm) × quantity) / 1000
```

### 5.2 `computeBoxWeightKg(boxes: Box[]): number` (verification only)

```
Σ(box.weight_kg)
```

Compare to invoice weight in UI; **do not** feed into cost engine as `cargo_kg`.

### 5.3 `computeWeightDelta(items: LineItem[], invoiceWeightKg: number): { estimated: number, actual: number, delta: number }`

`actual` = **invoice** weight (`total_weight_kg`), not Σ boxes.

### 5.4 `computePackageWeightAdjustments(items: LineItem[], invoiceTotalKg: number): WeightAdjustment[]`

Distributes `(invoiceTotalKg − estimated)` into line `package_weight_gm` only. **Does not** mutate `shipments.total_weight_kg`.

```typescript
export interface WeightAdjustment {
  item_id: number;
  new_package_weight_gm: number;
  per_unit_delta_gm: number;
}
```

**Algorithm**:
1. Calculate total estimated weight (gm) from items
2. Compute `delta = invoice_total_gm - estimated_total_gm`
3. For each item: `share = item_gross_weight / total_gross_weight`
4. `per_unit_delta = (delta × share) / quantity`
5. `new_package_weight = current_package_weight + per_unit_delta`
6. Remainder from rounding assigned to heaviest item
7. Validation: reject if any `new_package_weight < 0`

---

## 6. Price Balance (`priceBalance.ts`)

### 6.1 `computeEstimatedPurchaseTotal(items: LineItem[]): number`

```
Σ(unit_purchase_price × quantity)
```

### 6.2 `computePurchaseDelta(items: LineItem[], invoiceTotal: number): { estimated: number, actual: number, delta: number }`

Simple comparison.

### 6.3 `computePriceAdjustments(items: LineItem[], actualTotal: number): PriceAdjustment[]`

Distributes price delta proportionally across items by their current purchase value share.

```typescript
export interface PriceAdjustment {
  item_id: number;
  new_unit_purchase_price: number;
  per_unit_delta: number;
}
```

**Algorithm**:
1. Calculate total estimated purchase from items
2. Compute `delta = actual_total - estimated_total`
3. For each item: `share = item_purchase_value / total_purchase_value`
4. `per_unit_delta = (delta × share) / quantity`
5. `new_price = current_price + per_unit_delta`
6. Remainder from rounding assigned to highest-value item
7. Validation: reject if any `new_price < 0`

---

## 7. What Moves vs What Stays

### Moves into `shared/shipment-engine/`
| Current File | Becomes |
|---|---|
| `procurement_stock/utils/landedCost.ts` | **Done** → `shipment-engine/costEngine.ts` (+ thin re-export) |
| `procurement_stock/utils/costEntriesCosting.ts` (pure helpers) | **Done** → `shipment-engine/costEngine.ts` (+ thin adapter for `isShipmentCostFinalized`) |
| `procurement_stock/utils/landedCost.test.ts` | **Done** → `shipment-engine/__tests__/costEngine.test.ts` |
| `procurement_stock/utils/weightBalance.ts` | Later extract → `shipment-engine/weightBalance.ts` |
| `procurement_stock/utils/purchaseBalance.ts` | Later extract → `shipment-engine/priceBalance.ts` |
| `procurement_stock/utils/weightBalance.test.ts` | Later → `shipment-engine/__tests__/weightBalance.test.ts` |

### Stays in `procurement_stock/` (module-specific orchestration)
| File | Reason |
|---|---|
| `applyShipmentPurchaseBalance.ts` | Calls Supabase RPC — orchestration, not pure computation |
| `applyShipmentWeightBalance.ts` | Same — side-effectful orchestration |
| `syncShipmentWeightToProduct.ts` | Product table mutation |
| `buildShipmentExcelWorkbook.ts` | Export/formatting concern |

---

## 8. Key Design Changes from Current Code

### 8.1 Input Source: Cost Entries Instead of Header Fields

**Before** (current `CostingShipmentInput`):
```typescript
{
  type: 'international',
  product_conversion_rate: 168.50,   // ← hardcoded on header
  cargo_conversion_rate: 1.00,       // ← hardcoded on header
  cargo_rate: 350,                   // ← hardcoded on header
  received_weight: 42.5,
  transaction_rate: null
}
```

**After** (new `CostEntry[]` + `ShipmentContext`):
```typescript
// Context — just type + weight
{ shipment_type: 'international', total_weight_kg: 42.5 }

// Entries — all rates come from here
[
  { cost_type: 'product', amount: 1250, exchange_rate: 168.50, payment_source: 'cash' },
  { cost_type: 'product', amount: 500,  exchange_rate: 170.00, payment_source: 'credit' },
  { cost_type: 'cargo',   amount: 14875, exchange_rate: 1.00,  payment_source: 'cash' }
]
```

### 8.2 Effective Rates are Computed, Never Stored

The engine computes `product_rate`, `cargo_rate`, and `blended_rate` from entries. These values are for display and for the finalization RPC — they are never written back to the shipment header.

### 8.3 Cargo Purchase is Derived from Entries

**Before**: `cargo_purchase = received_weight × cargo_rate` (header field).
**After**: `cargo_purchase = Σ(amount)` where `cost_type = 'cargo'` from entries. The weight × per-kg rate is now just how the user _enters_ the cost — the engine works with the final amount.

### 8.4 Day-one vs improved

| Mode | Entries |
| :--- | :--- |
| Current behaviour | One `product` + one `cargo` |
| Multi FX | Multiple `product` rows → weighted `effective_rate` |
| Duty / labor / … | Extra `cost_type` rows + `allocation` stub |

---

## 9. Usage Examples

### 9.1 Vue Component (Live Costing Preview)

Day-one live API (header-shaped preview; entry→header via `costingShipmentFromEntries`):

```typescript
import {
  calculateShipmentCostSummary,
  costingShipmentFromEntries,
} from 'src/shared/shipment-engine';

const costingShipment = costingShipmentFromEntries(shipment, costEntries, lineItems);
const summary = calculateShipmentCostSummary(costingShipment, lineItems);
// Preview only — never writes landed_cost_bdt
```

Target entry-first signature (`computeShipmentCostSummary`) remains the long-term shape in §4; adapters bridge until header rates are dropped.

### 9.2 Server RPC (Finalization)
```sql
-- Postgres function calls the same logic
-- Reads from shipment_cost_entries, computes effective rates,
-- stamps landed_cost_bdt, optionally posts wallet to tenant + payee
-- (never a shipment wallet; source_type/source_id = shipment)
```

### 9.3 Unit Tests
```typescript
import { computeEffectiveRates } from '../costEngine';

test('weighted average for multi-source product payments', () => {
  const rates = computeEffectiveRates([
    { cost_type: 'product', amount: 1250, exchange_rate: 168.50, currency_id: 1 },
    { cost_type: 'product', amount: 500,  exchange_rate: 170.00, currency_id: 1 },
  ]);
  // (1250×168.5 + 500×170) / 1750 = 168.928...
  expect(rates.product_rate).toBeCloseTo(168.93, 2);
});
```

---

## 10. Cost Stamping & Revision

Authority: [schema.md](./schema.md) §4. Engine **computes**; RPCs **stamp**.

### 10.1 When to stamp

| Event | What happens | Who |
| :--- | :--- | :--- |
| **Draft editing** (Stage 2) | Preview only — nothing written | Client |
| **Finalization** (Stage 3) | `costEngine` → write `shipment_items.landed_cost_bdt` | Server RPC |
| **Cost revision** (Stage 4) | Recompute → **re-stamp** `landed_cost_bdt` | Server RPC |

Stock rows are never updated for cost. Invoice lines are never rewritten for cost.

### 10.2 Revision delta helper (`costRevision.ts`) — optional

UI / confirmation dialog only (old→new stamp delta). **No** auto wallet post on revise. **Not** the source of true P&L (reports join current stamp × sold qty).

#### `computeStampDelta(oldStamps, newCosts): StampDeltaResult`

```typescript
export interface ItemStampDelta {
  item_id: number;
  old_landed_cost_bdt: number;
  new_landed_cost_bdt: number;
  delta_per_unit: number;        // new - old
  quantity: number;              // shipment line qty (or sold qty if caller passes it)
  total_delta: number;           // delta_per_unit × quantity
}

export interface StampDeltaResult {
  items: ItemStampDelta[];
  total_delta_bdt: number;
  has_change: boolean;           // |total_delta| > threshold
}
```

#### `buildOptionalWalletPayload(...)` (stub)

Only if wallet integration wants an explicit “cost changed” post. Prefer report join for investor / batch P&L; do not require a variance ledger table for day-one truth.

### 10.3 Downstream: provisional snapshot vs actual report

**At sale** (invoice / shop order) — copy stamp once:

```text
invoice_line: {
  sell_price: 3000,
  unit_cost_price / landed_cost_bdt: 2400   ← frozen from shipment_item.landed_cost_bdt
  shipment_item_id: …                      ← required for actual P&L join
}
```

| View | Formula |
| :--- | :--- |
| Provisional line margin | `sell − unit_cost_snapshot` (invoice only) |
| **Actual** batch / investor P&L | `Σ sell − Σ (current shipment_item.landed_cost_bdt × sold_qty)` |
| Optional adjustment column | `provisional_cogs − actual_cogs` |

Rules:

- Posted invoice cost snapshots are **immutable**
- Customer-facing docs show sell only; cost is admin-internal
- After revision, unsold stock “shows” the new stamp via join; sold qty truth moves via **report join**, not invoice mutation
