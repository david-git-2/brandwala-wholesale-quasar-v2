/**
 * Shared shipment cost-engine types.
 * Pure data shapes only — no DB / Vue / Pinia.
 *
 * Preview helpers never write `landed_cost_bdt`; stamping is server-side
 * (finalize / revise RPCs).
 */

/** Header-shaped rates used by day-one live preview (dual-path until header rates drop). */
export interface CostingShipmentInput {
  type: 'international' | 'local' | 'transfer';
  product_conversion_rate?: number;
  cargo_conversion_rate?: number;
  cargo_rate?: number;
  received_weight: number | null;
  transaction_rate?: number | null;
}

export interface CostingLineItemInput {
  purchase_price: number;
  product_weight: number; // grams
  package_weight: number; // grams
  ordered_quantity: number;
}

/** Minimal cost-entry slice for entry→header mapping and rate weighting. */
export interface CostEntryInput {
  cost_type: string;
  amount: number;
  exchange_rate: number;
}

export interface ShipmentCostSummary {
  quantity: number;
  packagingWeightKg: number;
  cargoWeightKg: number;
  goodsPurchase: number;
  cargoPurchase: number;
  totalPurchase: number;
  goodsCost: number;
  cargoCost: number;
  totalCost: number;
  transactionRate: number | null;
  /** Σ(unit cost × qty) using live rate — preview only */
  lineLandedCostTotal: number;
}

/** Optional UI helper: stamp before vs after a cost revision. */
export interface StampRevisionDelta {
  old_landed_cost_bdt: number;
  new_landed_cost_bdt: number;
  delta_bdt: number;
}
