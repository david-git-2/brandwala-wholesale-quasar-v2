import type { InventoryAccountingEntry } from 'src/modules/accounting/types'

import type { GlobalShipmentLedgerEntry } from '../types'

export const mapGlobalLedgerToAccountingEntry = (
  row: GlobalShipmentLedgerEntry,
): InventoryAccountingEntry => ({
  id: row.id,
  tenant_id: row.tenant_id,
  invoice_id: row.global_invoice_id,
  invoice_item_id: row.global_invoice_item_id,
  inventory_item_id: row.global_stock_id,
  shipment_id: row.shipment_id,
  shipment_item_id: row.shipment_item_id,
  product_id: row.product_id,
  quantity: row.quantity,
  return_quantity: row.return_quantity ?? 0,
  return_amount: row.return_amount ?? 0,
  cost_amount: row.cost_amount,
  sell_price_amount: row.sell_price_amount,
  total_cost_amount: row.total_cost_amount,
  total_sell_amount: row.total_sell_amount,
  gross_profit_amount: row.gross_profit_amount,
  status: row.status === 'paid' ? 'paid' : 'due',
  entry_date: row.entry_date,
  note: row.note,
  created_at: row.created_at,
  updated_at: row.updated_at ?? row.created_at,
  type: 'normal',
  sold_in_tenant_id: row.sold_in_tenant_id,
  is_charges: row.is_charge,
})
