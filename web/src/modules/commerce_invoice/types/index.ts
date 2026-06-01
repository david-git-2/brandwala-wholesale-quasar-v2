import type { Database } from 'src/types/supabase'

export type CommerceInvoice = Database['public']['Tables']['commerce_invoices']['Row']

export interface CommerceInvoiceServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}
