/** Local opex rows stored as `global_shipment_cost_entries` with cost_type = local. */
export type GlobalShipmentLocalCost = {
  id: number;
  parent_tenant_id: number;
  shipment_id: number;
  section_id: number | null;
  description: string;
  amount: number;
  currency_id: number | null;
  created_at: string;
  updated_at: string;
};

export type ShipmentLocalCostDraft = {
  localKey: string;
  id: number | null;
  description: string;
  amount: number | null;
  section_id: number | null;
  currency_id: number | null;
};
