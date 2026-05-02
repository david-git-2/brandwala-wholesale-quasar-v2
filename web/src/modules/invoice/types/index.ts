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

export type CreateInvoiceInput = Omit<Invoice, 'id' | 'created_at' | 'updated_at'>
export type UpdateInvoiceInput = {
  id: number
  patch: Partial<Omit<Invoice, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>>
}
export type DeleteInvoiceInput = { id: number }

export type InvoiceStoreState = {
  invoices: Invoice[]
  selectedInvoice: Invoice | null
  loading: boolean
  saving: boolean
  error: string | null
}
