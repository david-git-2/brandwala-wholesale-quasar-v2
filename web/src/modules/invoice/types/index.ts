export type SortOrder = 'asc' | 'desc'
export type FilterOperator = 'eq' | 'ilike' | 'gte' | 'lte' | 'in'

export type InvoicePaymentStatus = 'due' | 'partially_paid' | 'paid'
export type InvoiceStatus = 'draft' | 'issued' | 'partially_paid' | 'paid' | 'overdue' | 'cancelled'
export type InvoiceSourceType = 'order' | 'product_based_costing_file'
export type InvoiceItemSourceType = 'order_item' | 'product_based_costing_item'
export type InventoryAccountingStatus = 'due' | 'paid'
export type PaymentMethod = 'cash' | 'bank' | 'mobile_banking' | 'other'

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

export type InvoiceItem = {
  id: number
  tenant_id: number
  invoice_id: number
  source_item_type: InvoiceItemSourceType
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

export type InventoryAccountingEntry = {
  id: number
  tenant_id: number
  invoice_id: number | null
  invoice_item_id: number | null
  inventory_item_id: number
  product_id: number | null
  quantity: number
  cost_amount: number
  sell_price_amount: number
  total_cost_amount: number
  total_sell_amount: number
  gross_profit_amount: number
  status: InventoryAccountingStatus
  entry_date: string
  note: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export type InvoiceAccountingPayment = {
  id: number
  tenant_id: number
  inventory_accounting_entry_id: number
  amount: number
  payment_date: string
  payment_method: PaymentMethod | null
  reference_no: string | null
  note: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export type CreateInvoiceInput = Omit<Invoice, 'id' | 'created_at' | 'updated_at'>
export type UpdateInvoiceInput = { id: number; patch: Partial<Omit<Invoice, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }
export type DeleteInvoiceInput = { id: number }

export type CreateInvoiceItemInput = Omit<InvoiceItem, 'id' | 'created_at' | 'updated_at'>
export type UpdateInvoiceItemInput = { id: number; patch: Partial<Omit<InvoiceItem, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }
export type DeleteInvoiceItemInput = { id: number }

export type CreateInventoryAccountingEntryInput = Omit<InventoryAccountingEntry, 'id' | 'created_at' | 'updated_at'>
export type UpdateInventoryAccountingEntryInput = { id: number; patch: Partial<Omit<InventoryAccountingEntry, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }
export type DeleteInventoryAccountingEntryInput = { id: number }

export type CreateInvoiceAccountingPaymentInput = Omit<InvoiceAccountingPayment, 'id' | 'created_at' | 'updated_at'>
export type UpdateInvoiceAccountingPaymentInput = { id: number; patch: Partial<Omit<InvoiceAccountingPayment, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }
export type DeleteInvoiceAccountingPaymentInput = { id: number }

export type InvoiceStoreState = {
  invoices: Invoice[]
  invoiceItems: InvoiceItem[]
  accountingEntries: InventoryAccountingEntry[]
  payments: InvoiceAccountingPayment[]
  selectedInvoice: Invoice | null
  selectedInvoiceItem: InvoiceItem | null
  selectedAccountingEntry: InventoryAccountingEntry | null
  selectedPayment: InvoiceAccountingPayment | null
  loading: boolean
  saving: boolean
  error: string | null
}
