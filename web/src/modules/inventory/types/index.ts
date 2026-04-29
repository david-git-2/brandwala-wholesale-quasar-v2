export type InventorySourceType = 'manual' | 'shipment'
export type InventoryStatus = 'active' | 'inactive'
export type InventoryMovementType =
  | 'received'
  | 'sold'
  | 'reserved'
  | 'unreserved'
  | 'damaged'
  | 'stolen'
  | 'expired'
  | 'adjustment'

export type SortOrder = 'asc' | 'desc'
export type FilterOperator = 'eq' | 'ilike' | 'gte' | 'lte' | 'in'

export type InventoryListQuery = {
  tenant_id?: number
  filters?: Record<string, unknown>
  operators?: Record<string, FilterOperator>
  page?: number
  page_size?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: SortOrder
}

export type InventoryListPage<T> = {
  data: T[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type InventoryServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type InventoryItem = {
  id: number
  tenant_id: number
  source_type: InventorySourceType
  source_id: number | null
  name: string
  image_url: string | null
  cost: number | null
  barcode: string | null
  product_code: string | null
  manufacturing_date: string | null
  expire_date: string | null
  status: InventoryStatus
  created_at: string
  updated_at: string
}

export type InventoryStock = {
  id: number
  inventory_item_id: number
  available_quantity: number
  reserved_quantity: number
  damaged_quantity: number
  stolen_quantity: number
  expired_quantity: number
  created_at: string
  updated_at: string
}

export type InventoryQuantities = {
  available: number
  reserved: number
  damaged: number
  stolen: number
  expired: number
}

export type InventoryItemWithStock = InventoryItem & {
  stock: InventoryStock | null
  shipment: {
    shipment_item: Record<string, unknown> | null
    shipment: Record<string, unknown> | null
  } | null
  quantities: InventoryQuantities
}

export type InventoryMovement = {
  id: number
  inventory_item_id: number
  type: InventoryMovementType
  quantity: number
  previous_quantity: number
  new_quantity: number
  note: string | null
  created_by: string | null
  created_at: string
}

export type CreateInventoryItemInput = Omit<InventoryItem, 'id' | 'created_at' | 'updated_at'>
export type UpdateInventoryItemInput = {
  id: number
  patch: Partial<
    Pick<
      InventoryItem,
      | 'source_type'
      | 'source_id'
      | 'name'
      | 'image_url'
      | 'cost'
      | 'barcode'
      | 'product_code'
      | 'manufacturing_date'
      | 'expire_date'
      | 'status'
    >
  >
}
export type DeleteInventoryItemInput = { id: number }

export type CreateInventoryStockInput = Omit<InventoryStock, 'id' | 'created_at' | 'updated_at'>
export type UpdateInventoryStockInput = {
  id: number
  patch: Partial<
    Pick<
      InventoryStock,
      | 'available_quantity'
      | 'reserved_quantity'
      | 'damaged_quantity'
      | 'stolen_quantity'
      | 'expired_quantity'
    >
  >
}
export type DeleteInventoryStockInput = { id: number }

export type CreateInventoryMovementInput = Omit<InventoryMovement, 'id' | 'created_at'>
export type UpdateInventoryMovementInput = {
  id: number
  patch: Partial<
    Pick<InventoryMovement, 'type' | 'quantity' | 'previous_quantity' | 'new_quantity' | 'note'>
  >
}
export type DeleteInventoryMovementInput = { id: number }

export type InventoryStoreState = {
  items: InventoryItemWithStock[]
  stocks: InventoryStock[]
  movements: InventoryMovement[]
  selectedItem: InventoryItem | null
  selectedStock: InventoryStock | null
  selectedMovement: InventoryMovement | null
  total: number
  page: number
  page_size: number
  total_pages: number
  stock_total: number
  stock_page: number
  stock_page_size: number
  stock_total_pages: number
  movement_total: number
  movement_page: number
  movement_page_size: number
  movement_total_pages: number
  loading: boolean
  saving: boolean
  error: string | null
}
