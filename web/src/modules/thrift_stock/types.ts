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
  category_id: number;
  type_id: number;
  section: ThriftSection;
  shelf_id: number;
  color: string;
  size: string;
  condition: ThriftCondition;
  sku: string;
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
  };
  image_url?: string | undefined;
  origin_purchase_price?: number | undefined;
}
