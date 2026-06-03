import type { Database } from 'src/types/supabase'

export type CommerceAccounting = Database['public']['Tables']['commerce_accounting']['Row']

export type CommerceAccountingDetails = CommerceAccounting & {
  order_payment_status?: boolean | null
}

export interface CommerceAccountingServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}
