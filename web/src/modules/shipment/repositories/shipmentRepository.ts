import { supabase } from 'src/boot/supabase'

import type {
  AddShipmentItemFromProductInput,
  AddShipmentItemManualInput,
  BulkAddShipmentItemsFromProductInput,
  BulkDeleteShipmentItemsByProductInput,
  CreateShipmentInput,
  DeleteShipmentInput,
  DeleteShipmentItemQuantityInput,
  Shipment,
  ShipmentItem,
  UpdateShipmentInput,
  UpdateShipmentFieldInput,
} from '../types'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const db = supabase as any

const listShipments = async (tenantId: number): Promise<Shipment[]> => {
  const { data, error } = await db
    .from('shipments')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: false })

  if (error) {
    throw error
  }

  return (data as Shipment[] | null) ?? []
}

const getShipmentById = async (id: number): Promise<Shipment> => {
  const { data, error } = await db
    .from('shipments')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment not found.')
  }

  return data as Shipment
}

const createShipment = async (payload: CreateShipmentInput): Promise<Shipment> => {
  const { data, error } = await db.rpc('create_shipment', {
    p_name: payload.name,
    p_tenant_id: payload.tenant_id,
  })

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment was not created.')
  }

  return data as Shipment
}

const updateShipment = async (payload: UpdateShipmentInput): Promise<Shipment> => {
  const entries = Object.entries(payload.patch).filter(([, value]) => value !== undefined)

  if (!entries.length) {
    throw new Error('No fields provided for shipment update.')
  }

  const normalizedPatch = Object.fromEntries(entries)

  const { data, error } = await db
    .from('shipments')
    .update(normalizedPatch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment was not updated.')
  }

  return data as Shipment
}

const updateShipmentField = async (payload: UpdateShipmentFieldInput): Promise<Shipment> =>
  updateShipment({
    id: payload.id,
    patch: {
      [payload.field]: payload.value,
    },
  })

const deleteShipment = async (payload: DeleteShipmentInput): Promise<void> => {
  const { error } = await db.rpc('delete_shipment', {
    p_id: payload.id,
  })

  if (error) {
    throw error
  }
}

const listShipmentItems = async (shipmentId: number): Promise<ShipmentItem[]> => {
  const { data, error } = await db
    .from('shipment_items')
    .select('*')
    .eq('shipment_id', shipmentId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as ShipmentItem[] | null) ?? []
}

const addShipmentItemFromProduct = async (
  payload: AddShipmentItemFromProductInput,
): Promise<ShipmentItem> => {
  const { data, error } = await db.rpc('add_shipment_item_from_product', {
    p_shipment_id: payload.shipment_id,
    p_product_id: payload.product_id,
    p_quantity: payload.quantity,
  })

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment item was not added.')
  }

  return data as ShipmentItem
}

const addShipmentItemManual = async (
  payload: AddShipmentItemManualInput,
): Promise<ShipmentItem> => {
  const { data, error } = await db.rpc('add_shipment_item_manual', {
    p_shipment_id: payload.shipment_id,
    p_name: payload.name ?? null,
    p_quantity: payload.quantity ?? null,
    p_barcode: payload.barcode ?? null,
    p_product_code: payload.product_code ?? null,
    p_product_id: payload.product_id ?? null,
    p_image_url: payload.image_url ?? null,
    p_product_weight: payload.product_weight ?? null,
    p_package_weight: payload.package_weight ?? null,
    p_price_gbp: payload.price_gbp ?? null,
    p_received_quantity: payload.received_quantity ?? null,
    p_damaged_quantity: payload.damaged_quantity ?? null,
    p_stolen_quantity: payload.stolen_quantity ?? null,
  })

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment item was not added.')
  }

  return data as ShipmentItem
}

const bulkAddShipmentItemsFromProduct = async (
  payload: BulkAddShipmentItemsFromProductInput,
): Promise<ShipmentItem[]> => {
  const { data, error } = await db.rpc('bulk_add_shipment_items_from_product_ids', {
    p_shipment_id: payload.shipment_id,
    p_items: payload.items,
  })

  if (error) {
    throw error
  }

  return (data as ShipmentItem[] | null) ?? []
}

const deleteShipmentItemQuantity = async (
  payload: DeleteShipmentItemQuantityInput,
): Promise<boolean> => {
  const { data, error } = await db.rpc('delete_shipment_item_quantity', {
    p_id: payload.id,
    p_quantity: payload.quantity,
  })

  if (error) {
    throw error
  }

  return Boolean(data)
}

const bulkDeleteShipmentItemsByProduct = async (
  payload: BulkDeleteShipmentItemsByProductInput,
): Promise<number> => {
  const { data, error } = await db.rpc('bulk_delete_shipment_items_by_product_id', {
    p_shipment_id: payload.shipment_id,
    p_items: payload.items,
  })

  if (error) {
    throw error
  }

  return Number(data ?? 0)
}

export const shipmentRepository = {
  listShipments,
  getShipmentById,
  createShipment,
  updateShipment,
  updateShipmentField,
  deleteShipment,
  listShipmentItems,
  addShipmentItemFromProduct,
  addShipmentItemManual,
  bulkAddShipmentItemsFromProduct,
  deleteShipmentItemQuantity,
  bulkDeleteShipmentItemsByProduct,
}
