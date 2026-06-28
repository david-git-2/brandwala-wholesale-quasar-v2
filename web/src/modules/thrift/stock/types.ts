export type ThriftSection = 'MALE' | 'FEMALE' | 'UNISEX' | 'KIDS' | 'HOME';
export type ThriftCondition = 'NEW_WITH_TAGS' | 'EXCELLENT' | 'GOOD' | 'FAIR';
export type ThriftStockType = 'SINGLE' | 'BULK';
export type ThriftStockStatus = 'AVAILABLE' | 'OUT_OF_STOCK' | 'DAMAGED' | 'STOLEN';

export interface ThriftStockMeasurements {
  stock_id: number;
  tenant_id: number;
  bust_in?: number | null;
  waist_in?: number | null;
  hips_in?: number | null;
  length_in?: number | null;
  shoulder_width_in?: number | null;
  sleeve_length_in?: number | null;
  arm_circumference_in?: number | null;
  hem_width_in?: number | null;
  neck_opening_in?: number | null;
  sleeve_type?: string | null;
  neckline?: string | null;
  dress_style?: string | null;
  fabric_stretch?: string | null;
  lining?: boolean | null;
  closure_type?: string | null;
  measurement_notes?: string | null;
  inserted_by?: string;
  created_at?: string;
  updated_at?: string;
}

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
    listed_unit_price: number;
    is_listed_price_manual?: boolean;
    extra_expense_cost?: number;
  };
  image_url?: string | undefined;
  drive_file_id?: string | undefined;
  origin_unit_price?: number | undefined;
  extra_origin_unit_price?: number | undefined;
  additional_charges_cost?: number | undefined;
  measurements?: ThriftStockMeasurements | null;
}
