export type GlobalStockSearchField = 'name' | 'barcode' | 'product_code'

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
