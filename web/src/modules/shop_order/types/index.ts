// =========================================================
// shop_order domain types
// =========================================================

export type ShopType = 'vendor_catalog' | 'fixed_price' | 'dropship'
export type ShopOrderMode = 'procurement_intent' | 'checkout_fixed' | 'checkout_wholesale'

export interface Shop {
  id: number
  tenant_id: number
  name: string
  slug: string
  shop_type: ShopType
  vendor_code: string | null
  order_mode: ShopOrderMode
  is_negotiable: boolean
  show_stock_quantity: boolean
  default_currency_id: number | null
  global_stock_type_id: number | null
  is_active: boolean
  created_at: string
  updated_at: string
}

// ---- Payloads -------------------------------------------------------

export interface CreateShopPayload {
  tenant_id: number
  name: string
  slug: string
  shop_type: ShopType
  vendor_code?: string | null
  order_mode: ShopOrderMode
  is_negotiable: boolean
  show_stock_quantity: boolean
  default_currency_id?: number | null
  global_stock_type_id?: number | null
  is_active: boolean
}

export interface UpdateShopPayload {
  id: number
  tenant_id: number
  name: string
  slug: string
  order_mode: ShopOrderMode
  is_negotiable: boolean
  show_stock_quantity: boolean
  default_currency_id?: number | null
  global_stock_type_id?: number | null
  is_active: boolean
}

// ---- Service result wrapper -----------------------------------------

export type ShopServiceResult<T> =
  | { success: true; data: T }
  | { success: false; error: string }

// ---- Pinia state ----------------------------------------------------

export interface ShopOrderState {
  shops: Shop[]
  loadingShops: boolean
  saving: boolean
  error: string | null
}

export type ShopOrderStatus =
  | 'draft'
  | 'submitted'
  | 'cancelled'
  | 'priced'
  | 'negotiating'
  | 'confirmed'
  | 'placed'
  | 'fulfilled'

export interface ShopOrder {
  id: number
  tenant_id: number
  shop_id: number
  shop_name?: string
  customer_group_id: number
  customer_group_name?: string
  cart_id: number | null
  order_no: string
  name: string
  shop_type_snapshot: ShopType
  order_mode_snapshot: ShopOrderMode
  is_negotiable_snapshot: boolean
  status: ShopOrderStatus
  negotiate_round: number
  cargo_rate: number | null
  conversion_rate: number | null
  profit_rate: number | null
  recipient_name: string | null
  recipient_phone: string | null
  shipping_address: string | null
  billing_profile_id: number | null
  placed_at: string | null
  fulfilled_at: string | null
  global_invoice_id: number | null
  created_by_email: string
  created_at: string
  updated_at: string
  item_count?: number
  total_amount?: number
}

export interface ShopOrderItem {
  id: number
  order_id: number
  product_id: number
  global_stock_id: number | null
  global_stock_allocation_id: number | null
  name: string
  image_url: string | null
  quantity: number
  unit_list_price_amount: number | null
  unit_list_price_currency_id: number | null
  unit_sell_price_amount: number | null
  unit_sell_price_currency_id: number | null
  unit_minimum_sell_price_amount: number | null
  unit_minimum_sell_price_currency_id: number | null
  customer_sell_price_amount: number | null
  customer_sell_price_currency_id: number | null
  customer_offer_amount: number | null
  customer_offer_currency_id: number | null
  staff_offer_amount: number | null
  staff_offer_currency_id: number | null
  final_price_amount: number | null
  final_price_currency_id: number | null
  ordered_quantity: number
  delivered_quantity: number
  returned_quantity: number
  procurement_pulled: boolean
  created_at: string
  updated_at: string
}

export * from './permissions'
export * from './pricing'
