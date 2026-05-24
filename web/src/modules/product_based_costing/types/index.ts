import type { Database } from 'src/types/supabase'

export type ProductBasedCostingFile =
  Database['public']['Tables']['product_based_costing_files']['Row'] & {
    default_shipment_id?: number | null
  }
export type ProductBasedCostingFileCreateInput =
  Database['public']['Tables']['product_based_costing_files']['Insert'] & {
    default_shipment_id?: number | null
  }
export type ProductBasedCostingFileUpdateInput =
  Database['public']['Tables']['product_based_costing_files']['Update'] & {
    id: number
    default_shipment_id?: number | null
  }
export type ProductBasedCostingFileDeleteInput = {
  id: number
}

export type ProductBasedCostingServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type ProductBasedCostingFileListInput = {
  page?: number
  page_size?: number
  search?: string
  status?: string | null
}

export type ProductBasedCostingFileListPage = {
  data: ProductBasedCostingFile[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}




export interface ProductBasedCostingItem {
  id: number
  product_based_costing_file_id: number | null
  product_id?: number | null
  name: string | null
  image_url: string | null
  note: string | null
  quantity: number | null
  delivered_quantity: number | null
  barcode: string | null
  product_code: string | null
  brand?: string | null
  vendor_code?: string | null
  market_code?: string | null
  web_link: string | null
  price_gbp: number | null
  product_weight: number | null
  package_weight: number | null
  offer_price: number | null
  status: string | null
  input_type?: 'manual' | 'product_list' | null
  assigned_shipment_id?: number | null
  created_at: string
  updated_at: string
}

export interface ProductBasedCostingItemCreateInput {
  product_based_costing_file_id?: number | null
  name?: string | null
  image_url?: string | null
  note?: string | null
  quantity?: number | null
  delivered_quantity?: number | null
  barcode?: string | null
  product_code?: string | null
  brand?: string | null
  vendor_code?: string | null
  market_code?: string | null
  web_link?: string | null
  price_gbp?: number | null
  product_weight?: number | null
  package_weight?: number | null
  offer_price?: number | null
  status?: string | null
  product_id?: number | null
  input_type?: 'manual' | 'product_list' | null
  assigned_shipment_id?: number | null
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
  total: number
  page: number
  page_size: number
  total_pages: number
  loading: boolean
  saving: boolean
  error: string | null
}
