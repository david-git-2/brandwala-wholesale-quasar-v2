import type { Database, Json } from 'src/types/database.types';

export type GlobalShipmentCostType = Database['public']['Enums']['global_shipment_cost_type'];

export type ShipmentCostPaymentSource = 'cash' | 'credit' | 'wallet';

/** Settlement payee — never `shipment` (shipment is source_*, not a wallet entity). */
export type ShipmentCostPayeeType = 'vendor' | 'cargo_company';

export type GlobalShipmentCostEntry = Database['public']['Tables']['global_shipment_cost_entries']['Row'];

/** Day-one editable types. Extra enum values stay stubbed (API allows; UI hides). */
export const DAY_ONE_COST_TYPES: GlobalShipmentCostType[] = ['product', 'cargo'];

export const STUB_COST_TYPES: GlobalShipmentCostType[] = [
  'duty',
  'insurance',
  'labor',
  'washing',
  'transport',
  'handling',
];

export interface UpsertShipmentCostEntryPayload {
  shipment_id: number;
  cost_type: GlobalShipmentCostType;
  amount: number;
  exchange_rate?: number;
  currency_id?: number | null;
  payment_source?: ShipmentCostPaymentSource | null;
  entity_type?: ShipmentCostPayeeType | null;
  entity_id?: number | null;
  allocation?: string | null;
  metadata?: Json;
  id?: number | null;
  section_id?: number | null;
}

export interface ReviseShipmentCostEntryInput {
  cost_type: GlobalShipmentCostType;
  amount: number;
  exchange_rate?: number;
  currency_id?: number | null;
  payment_source?: string | null;
  entity_type?: ShipmentCostPayeeType | null;
  entity_id?: number | null;
  allocation?: string | null;
  metadata?: Json;
  section_id?: number | null;
}


/** Local draft row for the Landed cost editor (may be unsaved). */
export interface CostEntryDraft {
  localKey: string;
  id: number | null;
  cost_type: GlobalShipmentCostType;
  amount: number;
  exchange_rate: number;
  payment_source: ShipmentCostPaymentSource | null;
  /** Who will be paid — intent only; null = costing-only. Never `shipment`. */
  entity_type: ShipmentCostPayeeType | null;
  entity_id: number | null;
  /** Cargo display helper — computed as amount ÷ weight; optional metadata on save. */
  per_kg_rate: number | null;
}

export interface CostEntriesSavePayload {
  drafts: CostEntryDraft[];
  /** Cargo invoice weight → `global_shipments.received_weight` */
  received_weight: number | null;
}
