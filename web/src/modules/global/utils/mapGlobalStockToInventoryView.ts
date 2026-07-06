import type { InventoryItemWithStock, Shipment } from '../types'

import type { GlobalStockRow } from '../types'

const calculateUsableQuantity = (params: {
  available: number
  reserved: number
  damaged: number
  stolen: number
}) => Math.max(0, params.available - params.reserved - params.damaged - params.stolen)

export const mapGlobalStockToInventoryView = (
  row: GlobalStockRow,
  shipment?: Shipment | null,
): InventoryItemWithStock => {
  const available = row.excellent_qty
  const reserved = row.reserved_qty
  const damaged = row.box_damage_qty
  const stolen = row.stolen_qty
  const expired = row.expired_qty
  const openBox = row.box_less_qty
  const usable = calculateUsableQuantity({ available, reserved, damaged, stolen })

  return {
    id: row.id,
    tenant_id: row.tenant_id,
    source_type: row.shipment_id != null ? 'shipment' : 'manual',
    source_id: row.shipment_id,
    product_id: row.product_id,
    name: row.name,
    image_url: row.image_url,
    cost: row.cost,
    barcode: row.barcode,
    product_code: row.product_code,
    manufacturing_date: null,
    expire_date: null,
    status: 'active',
    created_at: '',
    updated_at: '',
    stock: {
      id: row.id,
      inventory_item_id: row.id,
      available_quantity: available,
      reserved_quantity: reserved,
      damaged_quantity: damaged,
      stolen_quantity: stolen,
      expired_quantity: expired,
      open_box_quantity: openBox,
      created_at: '',
      updated_at: '',
    },
    shipment: shipment
      ? {
          shipment_item: null,
          shipment: shipment as unknown as Record<string, unknown>,
        }
      : null,
    quantities: {
      available,
      usable,
      reserved,
      damaged,
      stolen,
      expired,
      open_box: openBox,
    },
  }
}
