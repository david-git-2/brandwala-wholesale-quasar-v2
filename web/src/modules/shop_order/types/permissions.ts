export interface CustomerGroupShopProfile {
  id: number
  tenant_id: number
  customer_group_id: number
  is_active: boolean
  default_can_browse: boolean
  default_see_price: boolean
  default_can_add_to_cart: boolean
  default_can_place_order: boolean
  default_can_negotiate: boolean
  default_can_view_quantity: boolean
  default_can_set_dropship_price: boolean
  created_at?: string
  updated_at?: string
}

export interface ShopCustomerGroupAccess {
  id: number
  shop_id: number
  customer_group_id: number
  status: boolean
  can_browse: boolean | null
  see_price: boolean | null
  can_add_to_cart: boolean | null
  can_place_order: boolean | null
  can_negotiate: boolean | null
  can_view_quantity: boolean | null
  can_set_dropship_price: boolean | null
  price_tier_code: string | null
  credit_limit_amount: number | null
  credit_limit_currency_id: number | null
  created_at?: string
  updated_at?: string
}

export interface UpsertProfilePayload {
  tenant_id: number
  customer_group_id: number
  is_active: boolean
  default_can_browse: boolean
  default_see_price: boolean
  default_can_add_to_cart: boolean
  default_can_place_order: boolean
  default_can_negotiate: boolean
  default_can_view_quantity: boolean
  default_can_set_dropship_price: boolean
}

export interface UpsertAccessPayload {
  shop_id: number
  customer_group_id: number
  status: boolean
  can_browse: boolean | null
  see_price: boolean | null
  can_add_to_cart: boolean | null
  can_place_order: boolean | null
  can_negotiate: boolean | null
  can_view_quantity: boolean | null
  can_set_dropship_price: boolean | null
  price_tier_code: string | null
  credit_limit_amount: number | null
  credit_limit_currency_id: number | null
}
