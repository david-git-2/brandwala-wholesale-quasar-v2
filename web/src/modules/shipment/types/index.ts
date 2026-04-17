export type Shipment = {
  id: number
  tenant_id: number
  name: string
  product_conversion_rate: number | null
  cargo_conversion_rate: number | null
  cargo_rate: number | null
  weight: number | null
  received_weight: number | null
  created_at: string
  updated_at: string
}

export type ShipmentItem = {
  id: number
  shipment_id: number
  name: string | null
  quantity: number
  barcode: string | null
  product_code: string | null
  product_id: number | null
  image_url: string | null
  product_weight: number | null
  package_weight: number | null
  price_gbp: number | null
  received_quantity: number
  damaged_quantity: number
  stolen_quantity: number
  created_at: string
  updated_at: string
}

export type ShipmentOrder = {
  id: number
  shipment_id: number
  order_id: number
  created_at: string
  updated_at: string
}

export type CreateShipmentInput = {
  name: string
  tenant_id: number
}

export type ShipmentUpdateField =
  | 'name'
  | 'product_conversion_rate'
  | 'cargo_conversion_rate'
  | 'cargo_rate'
  | 'weight'
  | 'received_weight'

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

export type AddShipmentItemFromProductInput = {
  shipment_id: number
  product_id: number
  quantity: number
}

export type AddShipmentItemManualInput = {
  shipment_id: number
  name?: string | null
  quantity?: number | null
  barcode?: string | null
  product_code?: string | null
  product_id?: number | null
  image_url?: string | null
  product_weight?: number | null
  package_weight?: number | null
  price_gbp?: number | null
  received_quantity?: number | null
  damaged_quantity?: number | null
  stolen_quantity?: number | null
}

export type BulkAddShipmentItemsFromProductInput = {
  shipment_id: number
  items: Array<{ product_id: number; quantity: number }>
}

export type DeleteShipmentItemQuantityInput = {
  id: number
  quantity: number
}

export type BulkDeleteShipmentItemsByProductInput = {
  shipment_id: number
  items: Array<{ product_id: number; quantity: number }>
}

export type CreateShipmentOrderInput = {
  shipment_id: number
  order_id: number
}

export type UpdateShipmentOrderInput = {
  id: number
  shipment_id: number
  order_id: number
}

export type DeleteShipmentOrderInput = {
  id: number
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
  shipmentOrders: ShipmentOrder[]
  loading: boolean
  saving: boolean
  error: string | null
}
