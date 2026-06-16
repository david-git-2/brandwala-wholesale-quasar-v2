import type { Database } from 'src/types/supabase'

export type CommerceInvoice = Database['public']['Tables']['commerce_invoices']['Row']
export type CommerceOrderItem = Database['public']['Tables']['commerce_order_items']['Row']
export type CommerceOrder = Database['public']['Tables']['commerce_orders']['Row']

export type CommerceInvoiceDetailsOrder = Pick<
  CommerceOrder,
  'recipient_name' | 'recipient_phone' | 'shipping_address'
> | null

export type CommerceInvoiceDetailsItem = CommerceOrderItem & {
  products?: {
    name?: string | null
    product_code?: string | null
  } | null
  inventory_items?: {
    name?: string | null
    cost?: number | null
    product_code?: string | null
    barcode?: string | null
    source_type?: string | null
    source_id?: number | null
    shipment_name?: string | null
    tenant_shipment_id?: number | null
  } | null
}

export type CommerceInvoiceDetails = {
  invoice: CommerceInvoice
  order: CommerceInvoiceDetailsOrder
  items: CommerceInvoiceDetailsItem[]
}

export interface CommerceInvoiceServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}
