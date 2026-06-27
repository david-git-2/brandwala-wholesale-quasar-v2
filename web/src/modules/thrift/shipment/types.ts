export interface ThriftShipment {
  id: number;
  tenant_id: number;
  name: string;
  purchase_currency_id: number;
  cost_currency_id: number;
  cargo_conversion_rate?: number | null;
  cargo_rate?: number | null;
  product_conversion_rate?: number | null;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}
