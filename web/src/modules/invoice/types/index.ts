export type SortOrder = 'asc' | 'desc'
export type FilterOperator = 'eq' | 'ilike' | 'gte' | 'lte' | 'in'

export type InvoicePaymentStatus = 'due' | 'partially_paid' | 'paid'
export type InvoiceStatus = 'draft' | 'issued' | 'partially_paid' | 'paid' | 'overdue' | 'cancelled'
export type InvoiceSourceType = 'order' | 'product_based_costing_file'

export type InvoiceListQuery = {
  tenant_id?: number
  filters?: Record<string, unknown>
  operators?: Record<string, FilterOperator>
  page?: number
  page_size?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: SortOrder
}

export type InvoiceListPage<T> = {
  data: T[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type InvoiceServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type Invoice = {
  id: number
  tenant_id: number
  billing_profile_id: number | null
  customer_group_id: number | null
  invoice_no: string
  source_type: InvoiceSourceType
  source_id: number
  payment_status: InvoicePaymentStatus
  status: InvoiceStatus
  invoice_date: string
  due_date: string | null
  subtotal_amount: number
  discount_amount: number
  total_amount: number
  paid_amount: number
  note: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export type CreateInvoiceInput = {
  tenant_id: number
  invoice_no: string
  billing_profile_id: number | null
  customer_group_id?: number | null
  source_type?: InvoiceSourceType
  source_id?: number
  payment_status?: InvoicePaymentStatus
  status?: InvoiceStatus
  invoice_date?: string
  due_date?: string | null
  subtotal_amount?: number
  discount_amount?: number
  total_amount?: number
  paid_amount?: number
  note?: string | null
  created_by?: string | null
}
export type UpdateInvoiceInput = {
  id: number
  patch: Partial<Omit<Invoice, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>>
}
export type DeleteInvoiceInput = { id: number }

export type InvoiceItem = {
  id: number
  tenant_id: number
  invoice_id: number
  shipment_id: number | null
  source_item_type: 'order_item' | 'product_based_costing_item'
  source_item_id: number
  inventory_item_id: number | null
  product_id: number | null
  name_snapshot: string
  barcode_snapshot: string | null
  product_code_snapshot: string | null
  quantity: number
  cost_amount: number
  sell_price_amount: number
  line_discount_amount: number
  line_tax_amount: number
  line_total_amount: number
  created_at: string
  updated_at: string
}

export type CreateInvoiceItemInput = Omit<InvoiceItem, 'id' | 'created_at' | 'updated_at'>
export type UpdateInvoiceItemInput = {
  id: number
  patch: Partial<Omit<InvoiceItem, 'id' | 'tenant_id' | 'invoice_id' | 'created_at' | 'updated_at'>>
}
export type DeleteInvoiceItemInput = { id: number }

export type InvoiceStoreState = {
  invoices: Invoice[]
  invoiceItems: InvoiceItem[]
  selectedInvoice: Invoice | null
  loading: boolean
  saving: boolean
  error: string | null
}
