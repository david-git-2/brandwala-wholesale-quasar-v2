import type { Database } from 'src/types/supabase'

export type CommerceOrder = Database['public']['Tables']['commerce_orders']['Row']
export type CommerceOrderItem = Database['public']['Tables']['commerce_order_items']['Row']
export type CommerceOrderStatus = Database['public']['Enums']['commerce_order_status']
export type CommerceOrderSettings = Database['public']['Tables']['commerce_order_settings']['Row']

export interface CommerceOrderListQuery {
  tenant_id?: number | null
  page?: number
  page_size?: number
}

export interface CommerceOrderServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}
