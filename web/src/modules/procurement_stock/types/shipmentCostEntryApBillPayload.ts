import type { Json } from 'src/types/database.types';
import type { GlobalShipmentCostBucket, GlobalShipmentCostComponent } from './shipmentCostEntry';

/** Shape passed to `public.rpc_create_bill` (money spine v2). */
export type RpcCreateBillLinePayload = {
  item_kind: 'charge';
  description: string;
  quantity: number;
  unit_price: number;
  line_total: number;
  meta: { cost_entry_id: number };
};

export type RpcCreateBillPayload = {
  tenant_id: number;
  kind: 'shipment_cost_ap';
  source_entity: 'public.global_shipments';
  source_type: 'shipment_cost';
  source_id: string;
  source_key: string;
  idempotency_key: string;
  currency_code: string;
  from_profile_id: number | null;
  to_profile_id: number | null;
  counterparty_profile_id: number | null;
  auto_issue: boolean;
  note: string;
  meta: {
    ap_kind: GlobalShipmentCostBucket;
    shipment_id: number;
    ap_paper?: Json;
  };
  lines: RpcCreateBillLinePayload[];
};

export type ShipmentCostEntryBillPayloadSource = {
  id: number;
  shipment_id: number;
  cost_bucket: GlobalShipmentCostBucket;
  cost_component: GlobalShipmentCostComponent;
  amount: number;
  description?: string | null;
  metadata?: Record<string, unknown> | null;
  currency_id?: number | null;
};

export type BuildShipmentCostEntryBillPayloadResult = {
  payload: RpcCreateBillPayload;
  diagnostics: string[];
};
