export interface ThriftSettings {
  tenant_id: number;
  default_origin_purchase_price: number;
  created_at: string;
  updated_at: string;
}

export interface ThriftSettingsInput {
  defaultOriginPurchasePrice: number;
}
