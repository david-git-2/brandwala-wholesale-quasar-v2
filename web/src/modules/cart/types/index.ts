export type Cart = {
  id: number
  tenant_id: number
  store_id: number | null
  customer_group_id: number | null
  can_see_price: boolean
  created_at: string
  updated_at: string
}

export type CartItem = {
  id: number
  cart_id: number
  product_id: number | null
  name: string
  image_url: string | null
  price_gbp: number | null
  quantity: number
  minimum_quantity: number
  created_at: string
  updated_at: string
}

export type CartWithItems = {
  cart: Cart
  items: CartItem[]
}

export type CartWithItemDetails = {
  cart: Cart
  items: Array<CartItem & { product: Record<string, unknown> | null }>
}

export type CartCreateInput = {
  tenant_id: number
  store_id?: number | null
  customer_group_id?: number | null
  can_see_price?: boolean
}

export type CartUpdateInput = {
  id: number
  tenant_id?: number
  store_id?: number | null
  customer_group_id?: number | null
  can_see_price?: boolean
}

export type CartDeleteInput = {
  id: number
}

export type CartItemCreateInput = {
  cart_id: number
  product_id?: number | null
  name: string
  image_url?: string | null
  price_gbp?: number | null
  quantity?: number
  minimum_quantity?: number
}

export type CartItemUpdateInput = {
  id: number
  cart_id?: number
  product_id?: number | null
  name?: string
  image_url?: string | null
  price_gbp?: number | null
  quantity?: number
  minimum_quantity?: number
}

export type CartItemDeleteInput = {
  id: number
}

export type AddItemToCartInput = {
  tenant_id: number
  store_id?: number | null
  customer_group_id?: number | null
  can_see_price?: boolean
  product_id?: number | null
  name: string
  image_url?: string | null
  price_gbp?: number | null
  quantity: number
  minimum_quantity?: number
}

export type AddItemToCartResult = {
  cart: Cart
  item: CartItem
}

export type CartServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type CartStoreState = {
  carts: Cart[]
  items: CartItem[]
  cartSnapshot: CartWithItems | null
  cartDetails: CartWithItemDetails | null
  loading: boolean
  saving: boolean
  error: string | null
}
