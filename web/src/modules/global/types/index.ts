export type GlobalStockSearchField = 'name' | 'barcode' | 'product_code'

export type StockNetworkMode = 'page' | 'search' | 'invoice'

export type StockNetworkQuery = {
  context_tenant_id: number
  mode?: StockNetworkMode
  search?: string | null
  search_field?: GlobalStockSearchField | null
  product_id?: number | null
  status?: 'excellent' | 'box_less' | 'box_damage' | 'expired' | 'stolen' | 'reserved'
  shipment_id?: number | null
  exclude_zero_qty?: boolean
  page?: number
  page_size?: number
}

export type StockNetworkRow = {
  global_stock_id: number
  product_id: number | null
  name: string
  barcode: string | null
  product_code: string | null
  image_url: string | null
  cost: number
  shipment_id: number | null
  parent_tenant_id: number
  holding_tenant_id: number
  holding_tenant_name: string | null
  allocated_qty: number
  global_qty: number
  excellent_qty: number
  box_less_qty: number
  box_damage_qty: number
  expired_qty: number
  stolen_qty: number
  reserved_qty: number
  total_qty: number
  is_own_tenant: boolean
  is_pickable: boolean
  sort_rank: number
  product_group_key: string
}

export type StockNetworkPage = {
  data: StockNetworkRow[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type AllocationReconciliationRow = {
  stock_id: number
  status: string
  global_qty: number
  allocated_qty: number
  unallocated_qty: number
  is_reconciled: boolean
}

export type ChildStockAllocationRow = {
  id: number
  parent_tenant_id: number
  child_tenant_id: number
  stock_id: number
  status: string
  quantity: number
  is_display_only: boolean
  created_at: string
  updated_at: string
}

export type AllocateChildTenant = {
  id: number
  name: string
}

export type GlobalStockListQuery = {
  tenant_id: number
  page?: number
  page_size?: number
  search?: string | null
  search_field?: GlobalStockSearchField
  shipment_id?: number | null
  exclude_zero_qty?: boolean
}

export type GlobalStockListPage = {
  data: GlobalStockRow[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type GlobalStockRow = {
  id: number
  tenant_id: number
  parent_tenant_id: number
  name: string
  cost: number
  shipment_id: number | null
  product_id: number | null
  barcode: string | null
  product_code: string | null
  image_url: string | null
  excellent_qty: number
  box_less_qty: number
  box_damage_qty: number
  expired_qty: number
  stolen_qty: number
  reserved_qty: number
  total_qty: number
}

export type GlobalInvoiceRow = {
  id: number
  tenant_id: number
  parent_tenant_id: number
  invoice_no: string
  invoice_type: string
  payment_status: string
  invoice_date: string
  total_amount: number
  due_amount: number
  paid_amount: number
  billing_profile_id?: number | null
  billing_profile_name?: string | null
  recipient_name?: string | null
}

export type GlobalInvoiceType = 'retail' | 'wholesale' | 'dropship'
export type InvoiceCollectionSource = 'billing_profile' | 'recipient'

export type CreateGlobalInvoiceInput = {
  tenant_id: number
  invoice_no: string
  billing_profile_id: number
  invoice_type?: GlobalInvoiceType
  recipient_name?: string | null
  recipient_phone?: string | null
  recipient_address?: string | null
  recipient_party_id?: number | null
  middle_man_payout_amount?: number | null
  note?: string | null
}

export type GlobalInvoiceCreated = GlobalInvoiceRow & {
  note: string | null
  customer_group_id: number | null
  billing_profile_id: number | null
  recipient_party_id: number | null
  recipient_name: string | null
  recipient_phone: string | null
  recipient_address: string | null
  source_module: string
  sold_in_tenant_id: number | null
  subtotal_amount: number
  discount_amount: number
}

export type GlobalInvoiceDetail = GlobalInvoiceCreated & {
  ordered_by_party_id: number | null
  face_subtotal_amount?: number
  accounting_subtotal_amount?: number
  collection_source?: InvoiceCollectionSource | null
  middle_man_payout_amount?: number
  middle_man_payout_status?: string | null
  billing_profiles?: {
    id: number
    name: string
    email: string | null
    phone: string | null
    address: string | null
    color: string | null
  } | null
}

export type GlobalInvoiceItemRow = {
  id: number
  invoice_id: number
  global_stock_id: number
  name_snapshot: string
  quantity: number
  cost_amount: number
  sell_price_amount: number
  recipient_price_amount?: number | null
  line_face_total_amount?: number | null
  line_discount_amount: number
  line_total_amount: number
}

export type InvoiceChargeLineRow = {
  id: number
  invoice_id: number
  charge_type: string
  amount: number
  note: string | null
}

export type BusinessPartyRow = {
  id: number
  tenant_id: number
  parent_tenant_id: number
  name: string
  party_type: string
  phone: string | null
  email: string | null
  address: string | null
  is_active: boolean
}

export type GlobalLedgerRow = {
  id: number
  tenant_id: number
  parent_tenant_id: number
  entry_date: string
  quantity: number
  cost_amount: number
  sell_price_amount: number
  gross_profit_amount: number
  status: string
  note: string | null
  is_charge: boolean
}

export type GlobalShipmentAccountingRow = {
  id: number
  shipment_id: number
  buy_cost_total: number
  sell_total: number
  gross_profit_total: number
  refreshed_at: string
}

export type GlobalInvoiceAccountingRow = {
  id: number
  global_invoice_id: number
  subtotal_amount: number
  charge_total: number
  total_amount: number
  gross_profit_total: number
  refreshed_at: string
}

export type ParentCashCirculation = {
  investor_capital_in: number
  investor_capital_withdrawn: number
  investor_capital_deployed: number
  investor_capital_available: number
  customer_ar_due: number
  customer_ar_paid: number
  stock_cost_in_circulation: number
  realized_profit_mtd: number
  profit_distributed: number
}

export type GlobalShipmentInvestmentRow = {
  id: number
  shipment_id: number
  investor_id: number
  invested_amount: number
  cost_share_pct: number | null
  allocated_cost: number
  computed_profit: number
  profit_status: string
  status: string
}
