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

export type ProductBasedCostingStoreState = {
  items: ProductBasedCostingFile[]
  loading: boolean
  saving: boolean
  error: string | null
}
