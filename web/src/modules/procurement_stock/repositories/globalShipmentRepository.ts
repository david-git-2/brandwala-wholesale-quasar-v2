import { supabase } from 'src/boot/supabase'

const db = supabase as any

export interface GlobalShipment {
  id: number
  parent_tenant_id: number
  name: string
  tenant_shipment_id: number | null
  type: 'domestic' | 'international'
  status: string
  shipment_purchase_currency_id: number | null
  shipment_cost_currency_id: number | null
  product_conversion_rate: number
  cargo_conversion_rate: number
  cargo_rate: number
  received_weight: number | null
  received_date: string | null
  transaction_rate: number | null
  stock_ready: boolean
  created_at: string
  updated_at: string
}

export interface GlobalShipmentItem {
  id: number
  shipment_id: number
  product_id: number | null
  vendor_id: number | null
  name: string
  ordered_quantity: number
  image_url: string | null
  add_method: 'order' | 'costing' | 'manual'
  purchase_price: number
  product_weight: number
  package_weight: number
  barcode: string | null
  product_code: string | null
  source_child_tenant_id: number | null
  source_type: string | null
  source_id: number | null
  sort_order?: number
  created_at: string
  updated_at: string
}

export interface PaginationMeta {
  total: number
  page: number
  pageSize: number
  totalPages: number
}

export interface PaginatedResult<T> {
  data: T[]
  meta: PaginationMeta
}

const getById = async (id: number): Promise<GlobalShipment> => {
  const { data, error } = await db
    .from('global_shipments')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }
  return data as GlobalShipment
}

const listPaginated = async (
  tenantId: number,
  page: number = 1,
  pageSize: number = 20,
  search?: string,
  status?: string,
): Promise<PaginatedResult<GlobalShipment>> => {
  const { data, error } = await db.rpc('list_global_shipments_paginated', {
    p_tenant_id: tenantId,
    p_page: page,
    p_page_size: pageSize,
    p_search: search || null,
    p_status: status || null,
  })

  if (error) {
    throw error
  }

  const result = data as {
    data: GlobalShipment[]
    meta: {
      total: number
      page: number
      page_size: number
      total_pages: number
    }
  }

  return {
    data: result.data || [],
    meta: {
      total: result.meta?.total || 0,
      page: result.meta?.page || page,
      pageSize: result.meta?.page_size || pageSize,
      totalPages: result.meta?.total_pages || 1,
    },
  }
}

const createShipment = async (
  tenantId: number,
  payload: {
    name: string
    type: 'domestic' | 'international'
    shipment_purchase_currency_id: number | null
    shipment_cost_currency_id: number | null
  },
): Promise<GlobalShipment> => {
  const { data, error } = await db
    .from('global_shipments')
    .insert([
      {
        parent_tenant_id: tenantId,
        name: payload.name.trim(),
        type: payload.type,
        shipment_purchase_currency_id: payload.shipment_purchase_currency_id,
        shipment_cost_currency_id: payload.shipment_cost_currency_id,
        status: 'Draft',
      },
    ])
    .select()
    .single()

  if (error) throw error
  return data as GlobalShipment
}

const updateShipment = async (
  id: number,
  payload: Partial<Omit<GlobalShipment, 'id' | 'created_at' | 'updated_at' | 'parent_tenant_id'>>,
): Promise<GlobalShipment> => {
  const { data, error } = await db
    .from('global_shipments')
    .update(payload)
    .eq('id', id)
    .select()
    .single()

  if (error) throw error
  return data as GlobalShipment
}

const deleteShipment = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipments').delete().eq('id', id)
  if (error) throw error
}

const listShipmentItems = async (shipmentId: number): Promise<GlobalShipmentItem[]> => {
  const { data, error } = await db
    .from('global_shipment_items')
    .select('*')
    .eq('shipment_id', shipmentId)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })

  if (error) throw error
  return (data as GlobalShipmentItem[] | null) ?? []
}

const updateShipmentItemsOrder = async (items: { id: number; sort_order: number }[]): Promise<void> => {
  const { error } = await db.rpc('update_global_shipment_items_order', {
    p_items: items,
  })

  if (error) throw error
}

export interface ApplyWeightBalanceAdjustment {
  item_id: number
  package_weight: number
}

export interface ApplyWeightBalanceRpcResult {
  estimated_kg: number
  actual_kg: number
  delta_kg: number
}

const applyWeightBalance = async (
  shipmentId: number,
  adjustments: ApplyWeightBalanceAdjustment[],
  transactionRate: number | null,
): Promise<ApplyWeightBalanceRpcResult> => {
  const { data, error } = await db.rpc('apply_global_shipment_weight_balance', {
    p_shipment_id: shipmentId,
    p_adjustments: adjustments,
    p_transaction_rate: transactionRate,
  })

  if (error) throw error
  return data as ApplyWeightBalanceRpcResult
}

const createShipmentItem = async (
  payload: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at'>,
): Promise<GlobalShipmentItem> => {
  const { data, error } = await db
    .from('global_shipment_items')
    .insert([payload])
    .select()
    .single()

  if (error) throw error
  return data as GlobalShipmentItem
}

const updateShipmentItem = async (
  id: number,
  payload: Partial<Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>>,
): Promise<GlobalShipmentItem> => {
  const { data, error } = await db
    .from('global_shipment_items')
    .update(payload)
    .eq('id', id)
    .select()
    .single()

  if (error) throw error
  return data as GlobalShipmentItem
}

const deleteShipmentItem = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipment_items').delete().eq('id', id)
  if (error) throw error
}

const checkShipmentStockReferences = async (shipmentId: number): Promise<boolean> => {
  // First get all items of this shipment
  const items = await listShipmentItems(shipmentId)
  if (!items.length) return false

  const itemIds = items.map((i) => i.id)
  const { data, error } = await db
    .from('global_stocks')
    .select('id')
    .in('shipment_item_id', itemIds)
    .limit(1)

  if (error) throw error
  return (data && data.length > 0) || false
}

const checkShipmentItemStockReferences = async (itemId: number): Promise<boolean> => {
  const { data, error } = await db
    .from('global_stocks')
    .select('id')
    .eq('shipment_item_id', itemId)
    .limit(1)

  if (error) throw error
  return (data && data.length > 0) || false
}

export const globalShipmentRepository = {
  getById,
  listPaginated,
  createShipment,
  updateShipment,
  deleteShipment,
  listShipmentItems,
  createShipmentItem,
  updateShipmentItem,
  deleteShipmentItem,
  checkShipmentStockReferences,
  checkShipmentItemStockReferences,
  updateShipmentItemsOrder,
  applyWeightBalance,
}
