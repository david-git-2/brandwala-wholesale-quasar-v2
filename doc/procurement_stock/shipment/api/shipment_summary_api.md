# Shipment Summary API

Consolidated summary endpoint for shipment overview, KPIs, and financial/logistics metrics.

Consumes the shipment header, associated `global_shipment_items`, `shipment_cost_entries`, and `shipment_boxes` to provide calculated aggregates without requiring multiple round-trips.

---

## 1. Interface & Data Shape

```typescript
export interface ShipmentSummaryKPIs {
  // Quantities & Counts
  total_lines: number;
  total_ordered_quantity: number;
  total_received_quantity: number;
  
  // Weights (kg)
  packaging_weight_kg: number;
  cargo_weight_kg: number;
  boxes_weight_kg: number;
  boxes_count: number;
  
  // Financials & Landed Cost
  purchase_currency_symbol: string;
  cost_currency_symbol: string;
  goods_purchase_total: number;
  cargo_purchase_total: number;
  total_purchase_amount: number;
  goods_cost_bdt: number;
  cargo_cost_bdt: number;
  total_landed_cost_bdt: number;
  avg_cost_per_unit_bdt: number;
  effective_exchange_rate: number | null;
  
  // Verification & Invoice Matching
  has_cargo_weight: boolean;
  has_product_invoice: boolean;
  weight_matched: boolean;
  purchase_matched: boolean;
  weight_delta_kg: number;
  purchase_delta_amount: number;
  matched_invoices_ratio: string; // e.g. "2/2" or "1/2"
  is_cost_finalized: boolean;
}
```

---

## 2. API Method (Client Repository)

### `globalShipmentRepository.getShipmentSummary(shipmentId: number)`

```typescript
const summary = await globalShipmentRepository.getShipmentSummary(shipmentId);
```

### Calculation Rules
1. **Goods Purchase**: Sum of `(item.ordered_quantity * item.purchase_price)` across all line items.
2. **Total Landed Cost**: Calculated via `costEngine` using active cost entries and line item weights.
3. **Cargo Weight**: `shipment.total_weight_kg ?? shipment.received_weight`.
4. **Weight Matched**: `Math.abs(packaging_weight_kg - cargo_weight_kg) <= 0.01`.
5. **Purchase Matched**: `Math.abs(product_cost_entries_total - goods_purchase_total) <= 0.05`.
