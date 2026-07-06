export type InventoryAccountingStatus = 'pending' | 'posted' | 'voided'

export type InventoryAccountingEntry = {
  id: number
  tenant_id: number
  invoice_id: number | null
  invoice_item_id: number | null
  inventory_item_id: number | null
  shipment_id: number | null
  shipment_name?: string | null
  shipment_item_id: number | null
  product_id: number | null
  quantity: number
  return_quantity?: number
  return_amount?: number
  cost_amount: number
  sell_price_amount: number
  total_cost_amount: number
  total_sell_amount: number
  gross_profit_amount: number
  status: InventoryAccountingStatus
  entry_date: string
  note: string | null
  created_by?: string | null
  created_at: string
  updated_at?: string
  type?: 'normal' | 'commerce'
  sold_in_tenant_id?: number | null
}
