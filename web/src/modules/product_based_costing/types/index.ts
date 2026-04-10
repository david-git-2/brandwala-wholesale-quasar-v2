import type { Database } from 'src/types/supabase'

export type ProductBasedCostingFile =
  Database['public']['Tables']['product_based_costing_files']['Row']
export type ProductBasedCostingFileCreateInput =
  Database['public']['Tables']['product_based_costing_files']['Insert']
export type ProductBasedCostingFileUpdateInput =
  Database['public']['Tables']['product_based_costing_files']['Update'] & {
    id: number
  }
export type ProductBasedCostingFileDeleteInput = {
  id: number
}

export type ProductBasedCostingServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}




export interface ProductBasedCostingItem {
  id: number
  product_based_costing_file_id: number | null
  product_id?: number | null
  name: string | null
  image_url: string | null
  quantity: number | null
  barcode: string | null
  product_code: string | null
  web_link: string | null
  price_gbp: number | null
  product_weight: number | null
  package_weight: number | null
  offer_price: number | null
  status: string | null
  created_at: string
  updated_at: string
}

export interface ProductBasedCostingItemCreateInput {
  product_based_costing_file_id?: number | null
  name?: string | null
  image_url?: string | null
  quantity?: number | null
  barcode?: string | null
  product_code?: string | null
  web_link?: string | null
  price_gbp?: number | null
  product_weight?: number | null
  package_weight?: number | null
  offer_price?: number | null
  status?: string | null
  product_id?: number | null
}

export interface ProductBasedCostingItemUpdateInput
  extends ProductBasedCostingItemCreateInput {
  id: number
}


export interface ProductBasedCostingStoreState {
  items: ProductBasedCostingFile[]
  item: ProductBasedCostingFile | null
  costingItems: ProductBasedCostingItem[]
  costingItem: ProductBasedCostingItem | null
  loading: boolean
  saving: boolean
  error: string | null
}
