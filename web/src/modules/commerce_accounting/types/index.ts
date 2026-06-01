import type { Database } from 'src/types/supabase'

export type CommerceAccounting = Database['public']['Tables']['commerce_accounting']['Row']

export interface CommerceAccountingServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}
