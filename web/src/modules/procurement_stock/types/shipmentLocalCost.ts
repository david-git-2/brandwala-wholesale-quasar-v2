/** P&L-only rows: `global_shipment_cost_entries` with `is_capitalizable = false` (often `other` / legacy `local`). */
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
