export interface ShopProductListing {
  id: number;
  tenant_id: number;
  shop_id: number;
  global_stock_allocation_id?: number | null;
  global_stock_id: number;
  product_id: number;
  sell_price_amount: number;
  sell_price_currency_id: number;
  minimum_sell_price_amount: number | null;
  minimum_sell_price_currency_id: number | null;
  unit_cost_amount?: number | null;
  shipment_item_id?: number | null;
  shipment_id?: number | null;
  show_quantity: boolean | null;
  display_quantity_override: number | null;
  is_active: boolean;
  is_price_locked?: boolean;
  is_quantity_locked?: boolean;
  quantity_override_type?: 'absolute' | 'relative';
  created_at: string;
  updated_at: string;
  // Joined Product
  product_name: string;
  product_image_url: string | null;
  product_barcode: string | null;
  product_code: string | null;
  product_brand: string | null;
  product_category: string | null;
  // Stock details
  allocated_quantity: number;
  available_to_sell: number;
}

export interface CandidateAllocation {
  allocation_id?: number;
  global_stock_id: number;
  stock_id: number;
  product_id: number;
  product_name: string;
  product_image_url: string | null;
  product_barcode: string | null;
  product_code: string | null;
  product_brand: string | null;
  product_category: string | null;
  allocated_quantity: number;
  minimum_sell_price_amount?: number | null;
  minimum_sell_price_currency_id?: number | null;
  unit_cost_amount?: number | null;
  shipment_item_id?: number | null;
  shipment_id?: number | null;
}

export interface UpsertListingPayload {
  tenant_id: number;
  shop_id: number;
  global_stock_allocation_id?: number | null;
  global_stock_id?: number | null;
  sell_price_amount: number;
  sell_price_currency_id: number;
  minimum_sell_price_amount?: number | null;
  minimum_sell_price_currency_id?: number | null;
  show_quantity?: boolean | null;
  display_quantity_override?: number | null;
  is_active?: boolean;
  id?: number | null;
  is_price_locked?: boolean;
  is_quantity_locked?: boolean;
  quantity_override_type?: 'absolute' | 'relative';
}

export interface ShopPricingRule {
  id: number;
  tenant_id: number;
  shop_id: number;
  markup_percentage: number;
  dropship_markup_percentage?: number;
  is_auto_publish: boolean;
  default_show_quantity?: boolean;
  default_add_quantity?: number;
  created_at: string;
  updated_at: string;
}

export interface UpsertShopPricingRulePayload {
  shop_id: number;
  markup_percentage: number;
  dropship_markup_percentage?: number;
  is_auto_publish: boolean;
  default_show_quantity?: boolean;
  default_add_quantity?: number;
}
