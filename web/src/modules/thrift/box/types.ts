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
