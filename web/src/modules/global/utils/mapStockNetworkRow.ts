import type { InventoryItemWithStock, Shipment } from '../types'

import type { GlobalStockRow, StockNetworkRow } from '../types'
import { mapGlobalStockToInventoryView } from './mapGlobalStockToInventoryView'

export const mapStockNetworkToGlobalStockRow = (row: StockNetworkRow): GlobalStockRow => ({
  id: row.global_stock_id,
  tenant_id: row.holding_tenant_id,
  parent_tenant_id: row.parent_tenant_id,
  name: row.name,
  cost: row.cost,
  shipment_id: row.shipment_id,
  product_id: row.product_id,
  barcode: row.barcode,
  product_code: row.product_code,
  image_url: row.image_url,
  excellent_qty: row.excellent_qty,
  box_less_qty: row.box_less_qty,
  box_damage_qty: row.box_damage_qty,
  expired_qty: row.expired_qty,
  stolen_qty: row.stolen_qty,
  reserved_qty: row.reserved_qty,
  total_qty: row.total_qty,
})

export const mapStockNetworkToInventoryView = (
  row: StockNetworkRow,
  shipment?: Shipment | null,
): InventoryItemWithStock => mapGlobalStockToInventoryView(mapStockNetworkToGlobalStockRow(row), shipment)

export type StockNetworkProductGroup = {
  key: string
  product_id: number | null
  name: string
  image_url: string | null
  barcode: string | null
  product_code: string | null
  cost: number
  global_stock_id: number
  shipment_id: number | null
  contexts: StockNetworkRow[]
}

export const groupStockNetworkRows = (rows: StockNetworkRow[]): StockNetworkProductGroup[] => {
  const groups = new Map<string, StockNetworkProductGroup>()

  for (const row of rows) {
    const key = row.product_group_key
    let group = groups.get(key)
    if (!group) {
      group = {
        key,
        product_id: row.product_id,
        name: row.name,
        image_url: row.image_url,
        barcode: row.barcode,
        product_code: row.product_code,
        cost: row.cost,
        global_stock_id: row.global_stock_id,
        shipment_id: row.shipment_id,
        contexts: [],
      }
      groups.set(key, group)
    }
    group.contexts.push(row)
  }

  return Array.from(groups.values())
}
