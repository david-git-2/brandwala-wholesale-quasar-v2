export type SortOrder = 'asc' | 'desc'
export type FilterOperator = 'eq' | 'ilike' | 'gte' | 'lte' | 'in'

export type AccountingListQuery = {
  tenant_id?: number
  filters?: Record<string, unknown>
  operators?: Record<string, FilterOperator>
  page?: number
  page_size?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: SortOrder
}

export type AccountingListPage<T> = {
  data: T[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type AccountingServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type InventoryAccountingStatus = 'due' | 'paid'
export type InventoryAccountingPaymentMethod = 'cash' | 'bank' | 'mobile_banking' | 'other'

export type InventoryAccountingEntry = {
  id: number
  tenant_id: number
  invoice_id: number | null
  invoice_item_id: number | null
  inventory_item_id: number
  shipment_id: number | null
  shipment_item_id: number | null
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
  payment_method: InventoryAccountingPaymentMethod | null
  reference_no: string | null
  note: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export type CreateInventoryAccountingEntryInput = Omit<
  InventoryAccountingEntry,
  'id' | 'created_at' | 'updated_at'
>
export type UpdateInventoryAccountingEntryInput = {
  id: number
  patch: Partial<
    Omit<InventoryAccountingEntry, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>
  >
}
export type DeleteInventoryAccountingEntryInput = { id: number }

export type CreateInvoiceAccountingPaymentInput = Omit<
  InvoiceAccountingPayment,
  'id' | 'created_at' | 'updated_at'
>
export type UpdateInvoiceAccountingPaymentInput = {
  id: number
  patch: Partial<
    Omit<InvoiceAccountingPayment, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>
  >
}
export type DeleteInvoiceAccountingPaymentInput = { id: number }

export type AccountingStoreState = {
  accountingEntries: InventoryAccountingEntry[]
  accountingPayments: InvoiceAccountingPayment[]
  loading: boolean
  saving: boolean
  error: string | null
}
