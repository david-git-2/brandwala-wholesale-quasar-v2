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

export type ProductListPage = {
  data: Product[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type ProductStoreState = {
  items: Product[]
  loading: boolean
  saving: boolean
  error: string | null
}

export type ProductBrand = Database['public']['Tables']['product_brands']['Row']
export type ProductBrandCreateInput = Database['public']['Tables']['product_brands']['Insert']
export type ProductBrandUpdateInput = Database['public']['Tables']['product_brands']['Update'] & {
  id: number
}
export type ProductBrandDeleteInput = {
  id: number
}

export type ProductCategory = Database['public']['Tables']['product_categories']['Row']
export type ProductCategoryCreateInput = Database['public']['Tables']['product_categories']['Insert']
export type ProductCategoryUpdateInput = Database['public']['Tables']['product_categories']['Update'] & {
  id: number
}
export type ProductCategoryDeleteInput = {
  id: number
}
