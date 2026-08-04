# Shipment Engine — Cost, Balance & Costing

> Reusable, pure-function computation layer for all shipment types.
> Consumes `shipment_cost_entries` + `shipment_items` + `shipment_boxes` — produces computed outputs.
>
> **Dual-phase design**: UI computes for live preview (no network cost), server computes for authoritative stamping & wallet posting.

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         shipment_engine/                              │
│                                                                      │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────┐  ┌────────────┐ │
│  │ costEngine.ts │  │weightBalance  │  │ price    │  │ cost       │ │
│  │               │  │  .ts          │  │ Balance  │  │ Variance   │ │
│  │ • effective   │  │ • estimated   │  │  .ts     │  │  .ts       │ │
│  │   rates       │  │   vs actual   │  │ • est vs │  │ • compute  │ │
│  │ • breakdown   │  │   weight      │  │   invoice│  │   variance │ │
│  │ • per-item    │  │ • pkg weight  │  │ • price  │  │ • build    │ │
│  │   landed cost │  │   adjustments │  │   adjust │  │   ledger   │ │
│  │ • summary     │  │ • remainder   │  │ • rest   │  │   payload  │ │
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
│  • Computed costs        │  • Finalization: stamp   │  • Unit tests  │
│  • Balance previews      │    landed_cost_bdt       │    with plain  │
│  • No network cost       │  • Variance: post ledger │    objects     │
│  • For UX only           │  • Authoritative         │                │
└──────────────────────────────────────────────────────────────────────┘
```

**Key Principle**: Every function in the engine is **pure** — takes plain objects as input, returns plain objects as output. No Supabase client, no Pinia store, no Vue reactivity inside.

---

## 2. File Location

```
web/src/shared/shipment-engine/
├── types.ts              # Shared input/output interfaces
├── costEngine.ts         # Effective rates, cost breakdown, landed cost
├── costVariance.ts       # Variance calculation & ledger payload builder
├── weightBalance.ts      # Weight delta calculation & package weight distribution
├── priceBalance.ts       # Price delta calculation & purchase price distribution
└── __tests__/
    ├── costEngine.test.ts
    ├── costVariance.test.ts
    ├── weightBalance.test.ts
    └── priceBalance.test.ts
```

> Located in `shared/` because it is consumed by multiple modules (`procurement_stock`, `thrift`, future v2 shipment module).

---

## 3. Shared Interfaces (`types.ts`)

### 3.1 Inputs

```typescript
/** A single cost/rate entry from shipment_cost_entries */
export interface CostEntry {
  cost_type: string;        // 'product' | 'cargo' | 'duty' | 'labor' | 'washing' | 'transport' | ...
  entity_type?: string;     // target wallet entity type if payment_source = 'wallet' (e.g. 'vendor', 'courier')
  entity_id?: number;       // target wallet entity ID if payment_source = 'wallet'
  currency_id: number | null;
  amount: number;           // in source currency
  exchange_rate: number;    // to base currency (BDT). 1.00 for local
  payment_source?: string;  // 'cash' | 'credit' | 'wallet'
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
  total_weight_kg: number | null;  // cargo invoice weight (received weight)
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

For `blended_rate` (international only): combines product + cargo weighted by total value.

### 4.2 `computeCostBreakdown(entries: CostEntry[], items: LineItem[], ctx: ShipmentContext): CostBreakdown`

Aggregates all cost entries into a structured breakdown:
- Groups by `cost_type`
- Computes `purchase_total` and `base_total` per group
- Determines `cargo_weight_kg` (invoice weight → fallback to estimated from items)

### 4.3 `computeItemLandedCost(item: LineItem, entries: CostEntry[], items: LineItem[], ctx: ShipmentContext): ItemLandedCost`

Per-item landed cost:

1. **Cargo allocation** — distributes total cargo cost to item proportional to its gross weight share:
   ```
   item_gross_weight = (product_weight_gm + package_weight_gm) × quantity
   cargo_share = (item_gross_weight / total_gross_weight) × total_cargo_purchase
   ```
   Falls back to even distribution by quantity when no weight basis exists.

2. **Purchase base** = `unit_purchase_price + (cargo_share / quantity)`

3. **Landed cost BDT**:
   - **Local**: `purchase_base` (rate = 1.00)
   - **International**: `purchase_base × blended_rate`

### 4.4 `computeShipmentCostSummary(entries: CostEntry[], items: LineItem[], ctx: ShipmentContext): ShipmentCostSummary`

Top-level aggregation function that calls the above and returns everything:
- Effective rates
- Full cost breakdown
- Per-item landed costs
- Grand total BDT

---

## 5. Weight Balance (`weightBalance.ts`)

### 5.1 `computeEstimatedWeightKg(items: LineItem[]): number`

```
Σ((product_weight_gm + package_weight_gm) × quantity) / 1000
```

### 5.2 `computeActualWeightKg(boxes: Box[]): number`

```
Σ(box.weight_kg)
```

### 5.3 `computeWeightDelta(items: LineItem[], invoiceWeightKg: number): { estimated: number, actual: number, delta: number }`

Simple comparison.

### 5.4 `computePackageWeightAdjustments(items: LineItem[], actualTotalKg: number): WeightAdjustment[]`

Distributes weight delta proportionally across items by their current gross weight share. Adjusts `package_weight_gm` per item.

```typescript
export interface WeightAdjustment {
  item_id: number;
  new_package_weight_gm: number;
  per_unit_delta_gm: number;
}
```

**Algorithm**:
1. Calculate total estimated weight (gm) from items
2. Compute `delta = actual_total_gm - estimated_total_gm`
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
| `procurement_stock/utils/landedCost.ts` | `shipment-engine/costEngine.ts` |
| `procurement_stock/utils/weightBalance.ts` | `shipment-engine/weightBalance.ts` |
| `procurement_stock/utils/purchaseBalance.ts` | `shipment-engine/priceBalance.ts` |
| `procurement_stock/utils/landedCost.test.ts` | `shipment-engine/__tests__/costEngine.test.ts` |
| `procurement_stock/utils/weightBalance.test.ts` | `shipment-engine/__tests__/weightBalance.test.ts` |

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

---

## 9. Usage Examples

### 9.1 Vue Component (Live Costing Preview)
```typescript
import { computeShipmentCostSummary } from '@/shared/shipment-engine/costEngine';

const summary = computed(() =>
  computeShipmentCostSummary(
    costEntries.value,    // from shipment_cost_entries query
    lineItems.value,      // from shipment_items query
    { shipment_type: shipment.value.shipment_type, total_weight_kg: shipment.value.total_weight_kg }
  )
);
```

### 9.2 Server RPC (Finalization)
```sql
-- Postgres function calls the same logic
-- Reads from shipment_cost_entries, computes effective rates,
-- then posts wallet ledger entries using the computed totals
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

## 10. Cost Stamping & Variance

### 10.1 Cost Stamping Rules

The engine computes costs, but **stamping** (writing to DB) only happens at two points:

| Event | What happens | Who does it |
|---|---|---|
| **Finalization** (Stage 3) | Engine computes → stamps `landed_cost_bdt` on each `shipment_item` | Server RPC |
| **Cost Revision** (Stage 4) | Engine recomputes → computes variance → re-stamps `landed_cost_bdt` → posts variance ledger entry | Server RPC |
| **Draft editing** (Stage 2) | Engine computes for live preview only | Client (UI) — nothing stored |

### 10.2 Variance Computation (`costVariance.ts`)

#### `computeCostVariance(oldCosts: ItemLandedCost[], newCosts: ItemLandedCost[]): CostVarianceResult`

Compares previously-stamped costs against newly-computed costs:

```typescript
export interface ItemVariance {
  item_id: number;
  old_landed_cost_bdt: number;
  new_landed_cost_bdt: number;
  variance_per_unit: number;     // new - old
  quantity: number;
  total_variance: number;        // variance_per_unit × quantity
}

export interface CostVarianceResult {
  items: ItemVariance[];
  total_variance_bdt: number;    // Σ(total_variance) across all items
  has_variance: boolean;         // |total_variance| > threshold
}
```

#### `buildVarianceLedgerPayload(variance: CostVarianceResult, shipmentId: number, costEntry: CostEntry): WalletLedgerEntry`

Builds the wallet ledger entry payload for posting:

```typescript
{
  entity_type: costEntry.entity_type,
  entity_id: costEntry.entity_id,
  type: variance.total_variance_bdt > 0 ? 'debit' : 'credit',
  amount: Math.abs(variance.total_variance_bdt),
  source_type: 'shipment_cost_variance',
  source_id: String(shipmentId),
  metadata: {
    items: variance.items,
    old_total: Σ(old costs),
    new_total: Σ(new costs)
  }
}
```

### 10.3 Order Cost Snapshots (Downstream)

When an order/invoice is created from shipment stock, the order line **snapshots** the cost:

```
order_line_item: {
  product_id: 105,
  sell_price: 3000,
  unit_cost_snapshot: 2400    ← frozen from landed_cost_bdt at time of sale
}
```

- Already-issued invoices/orders are **never retroactively modified**
- Cost variance appears only in **accounting reports** (Provisional COGS vs Actual COGS)
- The invoice/order shows **sell price only** to the customer; cost is internal admin view only
