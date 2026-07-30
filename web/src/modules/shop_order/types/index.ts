// =========================================================
// shop_order domain types
// =========================================================

export type ShopType = 'vendor_catalog' | 'fixed_price' | 'dropship';
export type ShopOrderMode = 'procurement_intent' | 'checkout_fixed' | 'checkout_wholesale';

export interface Shop {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  shop_type: ShopType;
  vendor_code: string | null;
  order_mode: ShopOrderMode;
  is_negotiable: boolean;
  show_stock_quantity: boolean;
  default_currency_id: number | null;
  global_stock_type_id: number | null;
  is_active: boolean;
  allow_delivery: boolean;
  buy_currency_id: number;
  sell_currency_id: number;
  pricing_method: 'direct_cost' | 'markup';
  markup_percentage: number;
  quantity_display_mode: 'original' | 'custom_override';
  default_print_charge_amount?: number;
  default_packing_charge_amount?: number;
  deduct_charges_from_margin?: boolean;
  deduct_print_from_margin?: boolean;
  deduct_packing_from_margin?: boolean;
  vendor_filters?: Array<{ vendor_code: string; brands: string[] }> | null;
  description?: string | null;
  category_ids?: number[];
  created_at: string;
  updated_at: string;
}

export interface ShopCategory {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  description: string | null;
  icon: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreateShopCategoryPayload {
  tenant_id: number;
  name: string;
  slug: string;
  description?: string | null;
  icon?: string;
  is_active?: boolean;
}

export interface UpdateShopCategoryPayload {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  description?: string | null;
  icon?: string;
  is_active?: boolean;
}

// ---- Payloads -------------------------------------------------------

export interface CreateShopPayload {
  tenant_id: number;
  name: string;
  slug: string;
  shop_type: ShopType;
  vendor_code?: string | null;
  order_mode: ShopOrderMode;
  is_negotiable: boolean;
  show_stock_quantity: boolean;
  default_currency_id?: number | null;
  global_stock_type_id?: number | null;
  is_active: boolean;
  allow_delivery: boolean;
  buy_currency_id?: number | null;
  sell_currency_id?: number | null;
  pricing_method?: 'direct_cost' | 'markup' | null;
  markup_percentage?: number;
  quantity_display_mode?: 'original' | 'custom_override' | null;
  default_print_charge_amount?: number;
  default_packing_charge_amount?: number;
  deduct_charges_from_margin?: boolean;
  deduct_print_from_margin?: boolean;
  deduct_packing_from_margin?: boolean;
  vendor_filters?: Array<{ vendor_code: string; brands: string[] }> | null;
  description?: string | null;
  category_ids?: number[];
}

export interface UpdateShopPayload {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  order_mode: ShopOrderMode;
  is_negotiable: boolean;
  show_stock_quantity: boolean;
  default_currency_id?: number | null;
  global_stock_type_id?: number | null;
  is_active: boolean;
  allow_delivery: boolean;
  buy_currency_id?: number | null;
  sell_currency_id?: number | null;
  pricing_method?: 'direct_cost' | 'markup' | null;
  markup_percentage?: number;
  quantity_display_mode?: 'original' | 'custom_override' | null;
  default_print_charge_amount?: number;
  default_packing_charge_amount?: number;
  deduct_charges_from_margin?: boolean;
  deduct_print_from_margin?: boolean;
  deduct_packing_from_margin?: boolean;
  vendor_filters?: Array<{ vendor_code: string; brands: string[] }> | null;
  description?: string | null;
  category_ids?: number[];
}

// ---- Service result wrapper -----------------------------------------

export type ShopServiceResult<T> = { success: true; data: T } | { success: false; error: string };

// ---- Pinia state ----------------------------------------------------

export interface ShopOrderState {
  shops: Shop[];
  loadingShops: boolean;
  saving: boolean;
  error: string | null;
}

export type ShopOrderStatus =
  | 'draft'
  | 'submitted'
  | 'costing_pending'
  | 'priced'
  | 'countered'
  | 'final_offered'
  | 'confirmed'
  | 'procuring'
  | 'ordered'
  | 'cancelled'
  | 'negotiating'
  | 'revised'
  | 'rejected'
  | 'expired'
  | 'placed'
  | 'fulfilled'
  | 'processing'
  | 'ready_for_pickup'
  | 'shipped'
  | 'delivered'
  | 'returned'
  | 'payment_received';


export interface ShopOrder {
  id: number;
  tenant_id: number;
  shop_id: number;
  shop_name?: string;
  customer_group_id: number;
  customer_group_name?: string;
  cart_id: number | null;
  order_no: string;
  name: string;
  shop_type_snapshot: ShopType;
  order_mode_snapshot: ShopOrderMode;
  is_negotiable_snapshot: boolean;
  status: ShopOrderStatus;
  negotiate_round: number;
  cargo_rate: number | null;
  conversion_rate: number | null;
  profit_rate: number | null;
  profit_basis?: 'purchase' | 'total_cost' | 'sale_price' | string | null;
  package_weight_kg?: number | null;
  recipient_name: string | null;
  recipient_phone: string | null;
  recipient_phone_secondary?: string | null;
  shipping_address: string | null;
  shipping_district?: string | null;
  shipping_thana?: string | null;
  recipient_profile_id?: number | null;
  billing_profile_id: number | null;
  placed_at: string | null;
  fulfilled_at: string | null;
  global_invoice_id: number | null;
  created_by_email: string;
  created_at: string;
  updated_at: string;
  cod_charge_amount?: number;
  delivery_charge_amount?: number;
  print_charge_amount?: number;
  packing_charge_amount?: number;
  discount_amount?: number;
  is_prepaid_snapshot?: boolean;
  delivery_instructions?: string | null;
  deduct_charges_from_margin?: boolean;
  deduct_cod_from_margin?: boolean;
  deduct_delivery_from_margin?: boolean;
  deduct_print_from_margin?: boolean;
  deduct_packing_from_margin?: boolean;
  item_count?: number;
  total_amount?: number;
  cod_collect_amount?: number | null;
  courier_name?: string | null;
  courier_awb_number?: string | null;
  tracking_url?: string | null;
  courier_remittance_ref?: string | null;
  courier_bank_trx_id?: string | null;
  collection_source?: string | null;
  payout_settlement_status?: string | null;
}

export interface ShopOrderItem {
  id: number;
  order_id: number;
  product_id: number;
  global_stock_id: number | null;
  global_stock_allocation_id: number | null;
  name: string;
  image_url: string | null;
  quantity: number;
  unit_list_price_amount: number | null;
  unit_list_price_currency_id: number | null;
  unit_sell_price_amount: number | null;
  unit_sell_price_currency_id: number | null;
  unit_minimum_sell_price_amount: number | null;
  unit_minimum_sell_price_currency_id: number | null;
  customer_sell_price_amount: number | null;
  customer_sell_price_currency_id: number | null;
  customer_offer_amount: number | null;
  customer_offer_currency_id: number | null;
  staff_offer_amount: number | null;
  staff_offer_currency_id: number | null;
  final_price_amount: number | null;
  final_price_currency_id: number | null;
  final_offer_amount?: number | null;
  final_offer_currency_id?: number | null;
  confirmed_quantity?: number | null;
  weight_kg?: number | null;
  cost_price_amount?: number | null;
  cost_price_currency_id?: number | null;
  customer_decision_status?: string | null;
  customer_decision_at?: string | null;
  negotiation_status?: string | null;
  staff_offer_at?: string | null;
  customer_counter_at?: string | null;
  final_offer_at?: string | null;
  ordered_quantity: number;
  delivered_quantity: number;
  returned_quantity: number;
  procurement_pulled: boolean;
  sku?: string | null;
  brand?: string | null;
  barcode?: string | null;
  note?: string | null;
  product_weight_gm?: number | null;
  package_weight_gm?: number | null;
  created_at: string;
  updated_at: string;
}

export * from './permissions';
export * from './pricing';
export * from './courierRemittance';

