export interface ThriftCategory {
  id: number;
  tenant_id: number | null;
  is_global: boolean;
  name: string;
  description?: string | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftType {
  id: number;
  tenant_id: number | null;
  is_global: boolean;
  name: string;
  description?: string | undefined;
  icon?: string | null;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

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

export interface ThriftBox {
  id: number;
  tenant_id: number;
  shipment_id: number;
  name: string;
  weight?: number | null;
  received_weight?: number | null;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftShelf {
  id: number;
  tenant_id: number;
  name: string;
  location_bay?: string | null;
  shelf_code: string;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}
