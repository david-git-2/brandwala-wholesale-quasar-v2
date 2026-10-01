import type { Database } from 'src/types/database.types';

export type GlobalShipmentLocalCost =
  Database['public']['Tables']['global_shipment_local_costs']['Row'];

export type ShipmentLocalCostDraft = {
  localKey: string;
  id: number | null;
  description: string;
  amount: number | null;
  section_id: number | null;
  currency_id: number | null;
};
