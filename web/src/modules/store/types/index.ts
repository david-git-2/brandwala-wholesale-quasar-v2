export type Store = {
  id: number
  name: string
  vendor_code: string | null
  tenant_id: number
  created_at: string
  updated_at: string
}

export type StoreAccess = {
  id: number
  store_id: number
  customer_group_id: number
  status: boolean
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
}

export type StoreAccessUpdateInput = {
  id: number
  status: boolean
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

export type StoreProductsRow = {
  product: Record<string, unknown>
  total_count: number
}

export type StoreProductsPage = {
  items: Record<string, unknown>[]
  total: number
}
