export type ThriftSection = 'MALE' | 'FEMALE' | 'UNISEX' | 'KIDS' | 'HOME';
export type ThriftCondition = 'NEW_WITH_TAGS' | 'EXCELLENT' | 'GOOD' | 'FAIR';
export type ThriftStockType = 'SINGLE' | 'BULK';
export type ThriftStockStatus = 'AVAILABLE' | 'OUT_OF_STOCK' | 'DAMAGED' | 'STOLEN';

export interface ThriftStock {
  id: number;
  tenant_id: number;
  shipment_id: number;
  name: string;
  brand_name?: string | undefined;
  category_id: number | null;
  type_id: number | null;
  section: ThriftSection | null;
  shelf_id?: number | null;
  color: string;
  size: string;
  condition: ThriftCondition | null;
  barcode: string;
  stock_type: ThriftStockType;
  quantity: number;
  box_id?: number | undefined;
  product_weight?: number | undefined;
  extra_weight?: number | undefined;
  status: ThriftStockStatus;
  note?: string | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
  pricing?: {
    cost_of_goods_sold: number;
    target_price: number;
    listed_price: number;
    extra_expense_cost?: number;
  };
  image_url?: string | undefined;
  drive_file_id?: string | undefined;
  origin_purchase_price?: number | undefined;
  extra_origin_purchase_expense?: number | undefined;
}
