export interface ThriftShipment {
  id: number;
  tenant_id: number;
  name: string;
  purchase_currency_id: number;
  cost_currency_id: number;
  cargo_conversion_rate?: number | null;
  cargo_rate?: number | null;
  product_conversion_rate?: number | null;
  total_cargo_weight_kg?: number | null;
  labor_total_cost?: number | null;
  transportation_total_cost?: number | null;
  washing_total_cost?: number | null;
  default_markup_rate?: number | null;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftShipmentWithStats extends ThriftShipment {
  unit_count: number;
  cargo_cost: number;
  ops_cost: number;
}
