import type { Database } from 'src/types/supabase'

export type Product = Database['public']['Tables']['products']['Row']
export type ProductCreateInput = Database['public']['Tables']['products']['Insert']
export type ProductUpdateInput = Database['public']['Tables']['products']['Update'] & {
  id: number
}
export type ProductDeleteInput = {
  id: number
}

export type ProductServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type ProductStoreState = {
  items: Product[]
  loading: boolean
  saving: boolean
  error: string | null
}
