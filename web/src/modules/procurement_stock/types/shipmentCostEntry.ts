import type { Database, Json } from 'src/types/database.types';

export type GlobalShipmentCostBucket = Database['public']['Enums']['global_shipment_cost_bucket'];
export type GlobalShipmentCostComponent = Database['public']['Enums']['global_shipment_cost_component'];

export type GlobalShipmentCostEntry = Database['public']['Tables']['global_shipment_cost_entries']['Row'];

export const PRODUCT_COST_BUCKET: GlobalShipmentCostBucket = 'material';
export const CARGO_COST_BUCKET: GlobalShipmentCostBucket = 'freight';
export const LOCAL_COST_BUCKET: GlobalShipmentCostBucket = 'other';
export const DEFAULT_COST_COMPONENT: GlobalShipmentCostComponent = 'subtotal';

export interface UpsertShipmentCostEntryPayload {
  shipment_id: number;
  cost_bucket: GlobalShipmentCostBucket;
  cost_component: GlobalShipmentCostComponent;
  is_capitalizable?: boolean;
  description?: string | null;
  amount: number;
  currency_id?: number | null;
  metadata?: Json;
  id?: number | null;
  section_id?: number | null;
}

export interface ReviseShipmentCostEntryInput {
  cost_bucket: GlobalShipmentCostBucket;
  cost_component: GlobalShipmentCostComponent;
  is_capitalizable?: boolean;
  amount: number;
  currency_id?: number | null;
  metadata?: Json;
  section_id?: number | null;
}

/** Local draft row for the Landed cost editor (may be unsaved). */
export interface CostEntryDraft {
  localKey: string;
  id: number | null;
  cost_bucket: GlobalShipmentCostBucket;
  cost_component: GlobalShipmentCostComponent;
  is_capitalizable?: boolean;
  description?: string | null;
  amount: number;
  /** Optional note / remark for this cost entry row */
  note?: string | null;
  /** Optional shipment section association */
  section_id?: number | null;
  /** Cargo display helper — computed as amount ÷ weight */
  per_kg_rate: number | null;
}

export interface CostEntriesSavePayload {
  drafts: CostEntryDraft[];
  /** Cargo invoice weight → `global_shipments.received_weight` */
  received_weight: number | null;
}
