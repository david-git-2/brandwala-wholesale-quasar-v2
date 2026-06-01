export interface CommerceCartItem {
  id: number
  product_id: number
  tenant_id: number
  customer_group_id: number
  quantity: number
  created_at: string
  updated_at: string
  // Joined fields
  name: string
  image_url: string | null
  price_bdt: number | null // cost from store_product_prices
  price_gbp: number | null // cost
  minimum_sell_price_bdt: number | null // retail floor from store_product_prices
  minimum_quantity: number // MOQ from products table
}

export interface AddCommerceItemInput {
  tenant_id: number
  store_id: number | null
  customer_group_id: number
  product_id: number
  quantity: number
  minimum_quantity?: number | undefined
}

export interface UpdateCommerceQtyInput {
  id: number
  quantity: number
}

export interface CommerceCartServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}

export interface CommerceCartStoreState {
  items: CommerceCartItem[]
  loading: boolean
  saving: boolean
  error: string | null
}
