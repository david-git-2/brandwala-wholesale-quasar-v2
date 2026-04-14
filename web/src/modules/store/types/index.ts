export type Store = {
  id: number
  name: string
  vendor_code: string | null
  tenant_id: number
  created_at: string
  updated_at: string
  see_price?: boolean
}

export type StoreAccess = {
  id: number
  store_id: number
  customer_group_id: number
  status: boolean
  see_price: boolean
  created_at: string
  updated_at: string
}

export type StoreCreateInput = {
  name: string
  vendor_code: string
  tenant_id: number
}

export type StoreUpdateInput = {
  id: number
  name: string
  vendor_code: string
}

export type StoreDeleteInput = {
  id: number
}

export type StoreAccessCreateInput = {
  store_id: number
  customer_group_id: number
  status?: boolean
  see_price?: boolean
}

export type StoreAccessUpdateInput = {
  id: number
  status?: boolean
  see_price?: boolean
}

export type StoreAccessDeleteInput = {
  id: number
}

export type StoreServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type StoreProductsQueryInput = {
  store_id: number
  fields?: string[] | null
  search?: string | null
  category?: string | null
  brand?: string | null
  sort_by?: string | null
  sort_dir?: string | null
  limit?: number
  offset?: number
}

export type StoreProductsPage = {
  data: Record<string, unknown>[]
  meta: {
    store_id: number
    limit: number
    offset: number
    current_page: number
    sort_by: string
    sort_dir: string
    total: number
    can_see_price: boolean
  }
}

export type StoreStoreState = {
  items: Store[]
  accessItems: StoreAccess[]
  productItems: Record<string, unknown>[]
  loading: boolean
  saving: boolean
  error: string | null
  productsTotal: number
  productsOffset: number
  productsPage: number
  productsPageSize: number
  productsCanSeePrice: boolean
}

export type StoreCart = {
  id: number
  tenant_id: number
  store_id: number | null
  customer_group_id: number | null
  can_see_price: boolean
  created_at: string
  updated_at: string
}

export type StoreCartItem = {
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

export type StoreCartPayload = {
  cart: StoreCart
  items: StoreCartItem[]
}

export type StoreCartDetailedPayload = {
  cart: StoreCart
  items: Array<StoreCartItem & { product: Record<string, unknown> | null }>
}

export type StoreCartCreateInput = {
  tenant_id: number
  store_id?: number | null
  customer_group_id?: number | null
  can_see_price?: boolean
}

export type StoreCartUpdateInput = {
  id: number
  tenant_id?: number
  store_id?: number | null
  customer_group_id?: number | null
  can_see_price?: boolean
}

export type StoreCartDeleteInput = {
  id: number
}

export type StoreCartItemCreateInput = {
  cart_id: number
  product_id?: number | null
  name: string
  image_url?: string | null
  price_gbp?: number | null
  quantity?: number
  minimum_quantity?: number
}

export type StoreCartItemUpdateInput = {
  id: number
  cart_id?: number
  product_id?: number | null
  name?: string
  image_url?: string | null
  price_gbp?: number | null
  quantity?: number
  minimum_quantity?: number
}

export type StoreCartItemDeleteInput = {
  id: number
}
