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
  skip_count?: boolean
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

export type GlobalShipmentLedgerEntry = GlobalLedgerRow & {
  shipment_id: number | null
  shipment_item_id: number | null
  global_invoice_id: number | null
  global_invoice_item_id: number | null
  global_stock_id: number | null
  product_id: number | null
  sold_in_tenant_id: number | null
  total_cost_amount: number
  total_sell_amount: number
  return_quantity?: number
  return_amount?: number
  created_at: string
  updated_at?: string
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

export type Shipment = {
  id: number
  name: string
  status?: string | null
  tenant_shipment_id?: number | null
}

export type InventoryItemWithStock = {
  id: number
  tenant_id: number
  source_type: string
  source_id: number | null
  product_id: number | null
  name: string
  image_url: string | null
  cost: number
  barcode: string | null
  product_code: string | null
  manufacturing_date: string | null
  expire_date: string | null
  status: string
  created_at: string
  updated_at: string
  stock: {
    id: number
    inventory_item_id: number
    available_quantity: number
    reserved_quantity: number
    damaged_quantity: number
    stolen_quantity: number
    expired_quantity: number
    open_box_quantity: number
    created_at: string
    updated_at: string
  }
  shipment: {
    shipment_item: null
    shipment: Record<string, unknown>
  } | null
  quantities: {
    available: number
    usable: number
    reserved: number
    damaged: number
    stolen: number
    expired: number
    open_box: number
  }
}
