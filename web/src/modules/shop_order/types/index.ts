// =========================================================
// shop_order domain types
// =========================================================

export type ShopType = 'vendor_catalog' | 'fixed_price' | 'dropship';
export type ShopOrderMode = 'procurement_intent' | 'checkout_fixed' | 'checkout_wholesale';
export type ShopStorefrontListingStatus = 'active' | 'inactive';

/** Stock grade tag snapshot for admin storefront preview. */
export interface ShopCatalogStockGrade {
  slug: string;
  label: string;
  color?: string | null;
}

/** Nested price object from browse/detail catalog RPCs. */
export interface ShopCatalogPrice {
  amount: number | null;
  currency_id: number | null;
  code: string | null;
  symbol: string | null;
}

/** Row from `browse_shop_catalog_for_customer` RPC. */
export interface ShopCatalogItem {
  product_id: number;
  product_name: string;
  product_image_url: string | null;
  product_barcode: string | null;
  product_code: string | null;
  product_brand: string | null;
  product_category: string | null;
  vendor_code: string | null;
  is_available: boolean;
  unit_price: ShopCatalogPrice | null;
  sell_price: ShopCatalogPrice | null;
  resell_minimum_price: ShopCatalogPrice | null;
  available_units: number | null;
  /** Real stock ATP (admin storefront preview). */
  real_available_units?: number | null;
  /** Listing display qty override; null falls back to real available. */
  display_quantity_override?: number | null;
  /** Admin storefront preview: average landed unit cost. */
  avg_cost?: ShopCatalogPrice | null;
  /** Admin storefront preview: listing on/off shop status. */
  listing_status?: ShopStorefrontListingStatus | null;
  /** Admin storefront preview: warehouse stock grade (e.g. box damage, open box). */
  stock_grade?: ShopCatalogStockGrade | null;
  global_stock_allocation_id: number | null;
  global_stock_id: number | null;
  minimum_order_quantity: number | null;
}

/** Row from `list_shop_storefront_listings_for_admin` RPC (admin Storefront tab). */
export interface ShopStorefrontAdminListing extends ShopCatalogItem {
  listing_id: number;
  show_quantity?: boolean | null;
  sell_price_amount?: number;
  sell_price_currency_id?: number;
  minimum_sell_price_amount?: number | null;
  minimum_sell_price_currency_id?: number | null;
}

export interface ShopStorefrontAdminListingsResult {
  data: ShopStorefrontAdminListing[];
  meta: {
    total: number;
    page: number;
    page_size: number;
    total_pages: number;
    shop?: Pick<
      Shop,
      | 'id'
      | 'name'
      | 'slug'
      | 'shop_type'
      | 'sell_currency_id'
      | 'buy_currency_id'
      | 'pricing_method'
      | 'markup_percentage'
      | 'quantity_display_mode'
    > | null;
  };
}

/** Row from `list_allocated_stock_for_shop` RPC (shop Stock tab). */
export interface ShopAllocatedStockRow {
  global_stock_id: number;
  shipment_item_id: number;
  shipment_id: number;
  shipment_name: string;
  item_name: string;
  product_id: number;
  product_code: string | null;
  barcode: string | null;
  image_url: string | null;
  product_brand: string | null;
  product_category: string | null;
  available_atp: number;
  total_stock_qty: number;
  unit_cost_amount: number;
  stock_grade: ShopCatalogStockGrade | null;
  is_listed_on_shop: boolean;
  listing_id: number | null;
}

export interface ShopAllocatedStockResult {
  data: ShopAllocatedStockRow[];
  meta: {
    total: number;
    page: number;
    page_size: number;
    total_pages: number;
  };
}

export interface ShopStorefrontShipmentCostRow {
  shipment_id: number;
  shipment_no: string;
  shipment_name: string;
  quantity: number;
  unit_cost_amount: number;
}

/** Response from `get_shop_storefront_listing_price_calculation` RPC. */
export interface ShopStorefrontListingPriceCalculation {
  listing: {
    listing_id: number;
    shop_id: number;
    product_id: number;
    product_name: string;
    product_code: string | null;
    product_image_url: string | null;
    global_stock_id: number;
    grade_tag_id: number | null;
    stock_grade: ShopCatalogStockGrade | null;
    is_active: boolean;
    is_price_locked: boolean;
  };
  shipment_costs: ShopStorefrontShipmentCostRow[];
  totals: {
    total_quantity: number;
    real_available_units: number;
    weighted_avg_cost: ShopCatalogPrice | null;
  };
  pricing: {
    display_quantity_override: number | null;
    suggested_display_quantity: number;
    sell_price: ShopCatalogPrice | null;
    suggested_sell_price: ShopCatalogPrice | null;
    resell_minimum_price: ShopCatalogPrice | null;
  };
  shop: Pick<
    Shop,
    'id' | 'shop_type' | 'pricing_method' | 'markup_percentage' | 'sell_currency_id' | 'buy_currency_id'
  >;
}

/** Row from `get_shop_catalog_product_for_customer` RPC. */
export interface ShopCatalogProductDetail extends ShopCatalogItem {
  country_of_origin: string | null;
  expire_date: string | null;
  unit_price_currency_code?: string | null;
  unit_price_currency_symbol?: string | null;
  minimum_sell_price_amount?: number | null;
  minimum_sell_price_currency_id?: number | null;
  minimum_sell_price_currency_code?: string | null;
  minimum_sell_price_currency_symbol?: string | null;
}

export interface ShopCatalogProductDetailResult {
  data: ShopCatalogProductDetail;
  meta: ShopCatalogBrowseResult['meta'];
}

export interface ShopCatalogRelatedResult {
  data: ShopCatalogItem[];
  meta: {
    category: string | null;
  };
}

export interface ShopCatalogBrowseResult {
  data: ShopCatalogItem[];
  meta: {
    total: number;
    page: number;
    page_size: number;
    total_pages: number;
    shop?: Shop | null;
    permissions?: any | null;
  };
}

/** Row from `search_shop_catalog_for_customer` RPC. */
export interface ShopCatalogSearchItem {
  shop_id: number;
  shop_slug: string;
  shop_name: string;
  product_id: number;
  product_name: string;
  product_image_url: string | null;
  product_barcode: string | null;
  product_code: string | null;
  product_brand: string | null;
  product_category: string | null;
  unit_price_amount: number | null;
  unit_price_currency_id: number | null;
  unit_price_currency_symbol: string | null;
}

export interface ShopCatalogSearchResult {
  data: ShopCatalogSearchItem[];
  meta: {
    total: number;
    page: number;
    page_size: number;
    total_pages: number;
  };
}

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
  vendor_code?: string | null;
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
  | 'ready_for_shipment'
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
  | 'payment_received'
  | 'reseller_paid';

export interface CustomerOrderListItem {
  id: number;
  shop_id: number;
  shop_name: string;
  shop_slug: string;
  shop_type_snapshot: ShopType;
  order_no: string;
  status: ShopOrderStatus;
  item_count: number;
  can_see_buy_price: boolean;
  can_see_sell_price: boolean;
  sell_currency_id: number | null;
  total_amount: number | null;
  currency_symbol: string | null;
  created_at: string;
}

export interface CustomerOrderDetailOrder {
  id: number;
  tenant_id: number;
  shop_id: number;
  shop_name: string | null;
  shop_slug: string | null;
  customer_group_id: number;
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
  first_offer_rate: number | null;
  final_offer_rate: number | null;
  profit_basis: 'purchase' | 'total_cost' | 'sale_price' | null;
  package_weight_kg: number | null;
  recipient_name: string | null;
  recipient_phone: string | null;
  recipient_phone_secondary: string | null;
  shipping_address: string | null;
  shipping_district: string | null;
  shipping_thana: string | null;
  recipient_profile_id: number | null;
  billing_profile_id: number | null;
  placed_at: string | null;
  fulfilled_at: string | null;
  shop_sell_currency_id: number | null;
  shop_buy_currency_id: number | null;
  shop_sell_currency_symbol: string | null;
  shop_buy_currency_symbol: string | null;
  created_at: string;
  updated_at: string;
  cod_charge_amount: number;
  delivery_charge_amount: number;
  print_charge_amount: number;
  packing_charge_amount: number;
  discount_amount: number;
  is_prepaid_snapshot: boolean;
  delivery_instructions: string | null;
  deduct_charges_from_margin: boolean;
  deduct_cod_from_margin: boolean;
  deduct_delivery_from_margin: boolean;
  deduct_print_from_margin: boolean;
  deduct_packing_from_margin: boolean;
  item_count: number;
  total_amount: number;
  cod_collect_amount: number | null;
  courier_name: string | null;
  courier_awb_number: string | null;
  tracking_url: string | null;
  payout_settlement_status: string | null;
}

export interface CustomerOrderDetail {
  order: CustomerOrderDetailOrder;
  items: ShopOrderItem[];
}

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
  first_offer_rate?: number | null;
  final_offer_rate?: number | null;
  profit_basis?: 'purchase' | 'total_cost' | 'sale_price' | null;
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
  shop_sell_currency_id?: number | null;
  shop_buy_currency_id?: number | null;
  shop_sell_currency_symbol?: string | null;
  shop_buy_currency_symbol?: string | null;
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
  is_first_offer_manual?: boolean | null;
  final_price_amount: number | null;
  final_price_currency_id: number | null;
  final_offer_amount?: number | null;
  final_offer_currency_id?: number | null;
  is_final_offer_manual?: boolean | null;
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
  returned_quantity: number;
  procurement_pulled: boolean;
  sku?: string | null;
  brand?: string | null;
  barcode?: string | null;
  note?: string | null;
  product_weight_gm?: number | null;
  package_weight_gm?: number | null;
  minimum_order_quantity?: number | null;
  created_at: string;
  updated_at: string;
}

export * from './permissions';
export * from './pricing';
export * from './courierRemittance';
export * from './staffShopOrderDetail';

