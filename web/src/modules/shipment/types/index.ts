export type ShipmentItemMethod = 'order' | 'costing' | 'manual'

export const SHIPMENT_STATUS_OPTIONS = [
  'Draft',
  'Order Placed',
  'Proforma Generated',
  'Payment Done',
  'Delivery Date Received',
  'Uk Warehouse Delivery Received',
  'Air Shipment Date Set',
  'Airport Arrival',
  'Airport Released',
  'Warehouse Received',
  'Added to Inventory',
] as const

export type ShipmentStatus = (typeof SHIPMENT_STATUS_OPTIONS)[number]

export type ShipmentType = 'local' | 'international'

export type Shipment = {
  id: number
  tenant_id: number
  tenant_shipment_id: number
  name: string
  status: ShipmentStatus
  product_conversion_rate: number | null
  cargo_conversion_rate: number | null
  cargo_rate: number | null
  transaction_rate: number | null
  inventory_added: boolean
  received_weight: number | null
  vendor_code: string | null
  market_code: string | null
  shipment_type: ShipmentType
  created_at: string
  updated_at: string
}

export type ShipmentItemReceivingSplitKey = 'standard' | 'box_damage' | 'expired' | 'boxless' | 'stolen'

export type ShipmentItemReceivingSplitValue = {
  qty: number
  note: string | null
}

export type ShipmentItemReceivingSplits = Record<ShipmentItemReceivingSplitKey, ShipmentItemReceivingSplitValue>

export type ShipmentItem = {
  id: number
  shipment_id: number
  order_id: number | null
  method: ShipmentItemMethod | null
  name: string | null
  quantity: number
  barcode: string | null
  product_code: string | null
  product_id: number | null
  image_url: string | null
  product_weight: number | null
  package_weight: number | null
  price_gbp: number | null
  cost_bdt: number | null
  marker_tag: 'price_reviewed' | 'issue' | 'done' | null
  inspected: boolean
  receiving_splits: ShipmentItemReceivingSplits | null
  created_at: string
  updated_at: string
}

export type BatchCodePc = {
  id: number
  shipment_id: number
  shipment_item_id: number | null
  product_code: string | null
  batch_id: string | null
  manufacturing_date: string | null
  expire_date: string | null
  created_at: string
  updated_at: string
}

export type CreateShipmentInput = {
  name: string
  tenant_id: number
  shipment_type?: ShipmentType
}

export type ShipmentUpdateField =
  | 'name'
  | 'status'
  | 'product_conversion_rate'
  | 'cargo_conversion_rate'
  | 'cargo_rate'
  | 'transaction_rate'
  | 'received_weight'
  | 'vendor_code'
  | 'market_code'
  | 'inventory_added'
  | 'shipment_type'

export type UpdateShipmentFieldInput = {
  id: number
  field: ShipmentUpdateField
  value: string | number | null
}

export type UpdateShipmentInput = {
  id: number
  patch: Partial<Pick<Shipment, ShipmentUpdateField>>
}

export type DeleteShipmentInput = {
  id: number
}

export type CopyShipmentInput = {
  id: number
}

export type AddShipmentItemFromProductInput = {
  shipment_id: number
  product_id: number
  quantity: number
  method?: ShipmentItemMethod | null
}

export type AddShipmentItemManualInput = {
  shipment_id: number
  order_id?: number | null
  method?: ShipmentItemMethod | null
  name?: string | null
  quantity?: number | null
  barcode?: string | null
  product_code?: string | null
  product_id?: number | null
  image_url?: string | null
  product_weight?: number | null
  package_weight?: number | null
  price_gbp?: number | null
  receiving_splits?: ShipmentItemReceivingSplits | null
  cost_bdt?: number | null
}

export type BulkAddShipmentItemsFromProductInput = {
  shipment_id: number
  items: Array<{ product_id: number; quantity: number }>
}

export type DeleteShipmentItemQuantityInput = {
  id: number
  quantity: number
}

export type UpdateShipmentItemInput = {
  id: number
  patch: Partial<
    Pick<
      ShipmentItem,
      | 'name'
      | 'quantity'
      | 'barcode'
      | 'product_code'
      | 'image_url'
      | 'order_id'
      | 'method'
      | 'price_gbp'
      | 'marker_tag'
      | 'product_weight'
      | 'package_weight'
      | 'inspected'
      | 'receiving_splits'
      | 'cost_bdt'
    >
  >
}

export type DeleteShipmentItemInput = {
  id: number
}

export type BulkDeleteShipmentItemsByProductInput = {
  shipment_id: number
  items: Array<{ product_id: number; quantity: number }>
}

export type CreateBatchCodePcInput = {
  shipment_id: number
  shipment_item_id?: number | null
  product_code?: string | null
  batch_id?: string | null
  manufacturing_date?: string | null
  expire_date?: string | null
}

export type BulkCreateBatchCodePcInput = {
  rows: CreateBatchCodePcInput[]
}

export type DeleteBatchCodePcInput = {
  id: number
}

export type DeleteAllBatchCodePcByShipmentInput = {
  shipment_id: number
}

export type ShipmentServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type ShipmentStoreState = {
  shipments: Shipment[]
  selectedShipment: Shipment | null
  shipmentItems: ShipmentItem[]
  batchCodePcRows: BatchCodePc[]
  loading: boolean
  saving: boolean
  error: string | null
  totalShipments: number
  currentPage: number
  pageSize: number
  totalPages: number
}

export type ShipmentReceiveItemSplit = {
  type: 'standard' | 'box_damage' | 'expired' | 'boxless' | 'stolen'
  qty: number
  note: string | null
}

export type ShipmentReceiveItemInput = {
  shipmentItemId: number
  splits: ShipmentReceiveItemSplit[]
}
