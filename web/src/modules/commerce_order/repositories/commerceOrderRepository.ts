import { supabase } from 'src/boot/supabase'
import type {
  CommerceOrder,
  CommerceOrderDetailsItem,
  CommerceOrderItem,
  CommerceOrderStatus,
  CommerceOrderSettings,
} from '../types'

const listCommerceOrders = async (
  tenantId: number,
  payload: {
    page: number
    page_size: number
    customer_group_id?: number | null
  }
): Promise<{
  data: (CommerceOrder & { customer_group_name?: string | null })[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}> => {
  const page = Math.max(1, payload.page || 1)
  const pageSize = Math.max(1, payload.page_size || 20)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase
    .from('commerce_orders')
    .select('*, customer_groups(name)', { count: 'exact' })
    .eq('tenant_id', tenantId)

  if (payload.customer_group_id != null) {
    query = query.eq('customer_group_id', payload.customer_group_id)
  }

  const { data, count, error } = await query
    .order('id', { ascending: false })
    .range(from, to)

  if (error) throw error

  const total = count || 0
  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  const formattedData = (data || []).map((row) => {
    const rowWithGroup = row as CommerceOrder & {
      customer_groups?: { name?: string | null } | null
    }
    return {
      ...rowWithGroup,
      customer_group_name: rowWithGroup.customer_groups?.name || null,
    }
  })

  return {
    data: formattedData,
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: totalPages,
    },
  }
}

const getCommerceOrderDetails = async (
  orderId: number,
): Promise<{ order: CommerceOrder; items: CommerceOrderDetailsItem[] }> => {
  const { data: order, error: orderError } = await supabase
    .from('commerce_orders')
    .select('*')
    .eq('id', orderId)
    .maybeSingle()

  if (orderError) throw orderError
  if (!order) throw new Error('Commerce Order not found.')

  const { data: items, error: itemsError } = await supabase
    .from('commerce_order_items')
    .select('*')
    .eq('order_id', orderId)

  if (itemsError) throw itemsError

  const itemRows = (items || []) as CommerceOrderItem[]
  const inventoryItemIds = Array.from(
    new Set(itemRows.map((item) => Number((item as CommerceOrderItem & { inventory_item_id?: number | null }).inventory_item_id || 0)).filter((id) => id > 0)),
  )

  const inventoryItemsById = new Map<number, { name?: string | null; cost?: number | null; product_code?: string | null; barcode?: string | null }>()

  if (inventoryItemIds.length > 0) {
    const { data: inventoryItems, error: inventoryItemsError } = await supabase
      .from('inventory_items')
      .select('id, name, cost, product_code, barcode')
      .in('id', inventoryItemIds)

    if (inventoryItemsError) throw inventoryItemsError

    for (const inventoryItem of inventoryItems || []) {
      inventoryItemsById.set(inventoryItem.id, {
        name: inventoryItem.name,
        cost: inventoryItem.cost,
        product_code: inventoryItem.product_code,
        barcode: inventoryItem.barcode,
      })
    }
  }

  return {
    order,
    items: itemRows.map((item) => {
      const inventoryItemId = Number(
        (item as CommerceOrderItem & { inventory_item_id?: number | null }).inventory_item_id || 0,
      )

      return {
        ...item,
        inventory_items: inventoryItemId > 0 ? inventoryItemsById.get(inventoryItemId) ?? null : null,
      }
    }),
  }
}

const updateCommerceOrderStatus = async (
  orderId: number,
  status: CommerceOrderStatus,
): Promise<CommerceOrder> => {
  const { data, error } = await supabase
    .from('commerce_orders')
    .update({ status })
    .eq('id', orderId)
    .select('*')
    .maybeSingle()

  if (error) throw error
  if (!data) throw new Error('Commerce Order not found.')
  return data
}

const placeCommerceOrder = async (payload: {
  tenant_id: number
  customer_group_id: number
  recipient_name: string
  recipient_phone: string
  shipping_address: string
  shipment_payment: number
  invoice_print_charge: number
  wrapping_charge: number
  cod: number
  delivery_charge: number
  is_delivery_charge_inclusive: boolean
  items: Array<{
    product_id: number
    image_url: string | null
    cost_bdt: number
    sell_price_bdt: number
    recipient_price_bdt: number
    quantity: number
    phone_invite_id?: string | null
  }>
}): Promise<number> => {
  const { data, error } = await supabase.rpc('place_commerce_order' as never, {
    p_tenant_id: payload.tenant_id,
    p_customer_group_id: payload.customer_group_id,
    p_recipient_name: payload.recipient_name,
    p_recipient_phone: payload.recipient_phone,
    p_shipping_address: payload.shipping_address,
    p_shipment_payment: payload.shipment_payment,
    p_invoice_print_charge: payload.invoice_print_charge,
    p_wrapping_charge: payload.wrapping_charge,
    p_cod: payload.cod,
    p_delivery_charge: payload.delivery_charge,
    p_is_delivery_charge_inclusive: payload.is_delivery_charge_inclusive,
    p_items: payload.items,
  } as never)

  if (error) throw error
  return Number(data)
}

const getCommerceOrderSettings = async (tenantId: number): Promise<CommerceOrderSettings | null> => {
  const { data, error } = await supabase
    .from('commerce_order_settings')
    .select('*')
    .eq('tenant_id', tenantId)
    .maybeSingle()

  if (error) throw error
  return data
}

const upsertCommerceOrderSettings = async (
  tenantId: number,
  payload: Omit<CommerceOrderSettings, 'tenant_id' | 'created_at' | 'updated_at'>,
): Promise<CommerceOrderSettings> => {
  const { data, error } = await supabase
    .from('commerce_order_settings')
    .upsert({
      tenant_id: tenantId,
      ...payload,
    })
    .select('*')
    .single()

  if (error) throw error
  return data
}

const updateCommerceOrderCharges = async (
  orderId: number,
  payload: {
    delivery_charge: number
    wrapping_charge: number
    cod: number
    shipment_payment: number
    is_delivery_charge_inclusive?: boolean
  },
): Promise<CommerceOrder> => {
  const { data, error } = await supabase
    .from('commerce_orders')
    .update(payload)
    .eq('id', orderId)
    .select('*')
    .maybeSingle()

  if (error) throw error
  if (!data) throw new Error('Commerce Order not found.')
  return data
}

const deleteCommerceOrder = async (orderId: number): Promise<void> => {
  const { error } = await supabase
    .from('commerce_orders')
    .delete()
    .eq('id', orderId)

  if (error) throw error
}

export const commerceOrderRepository = {
  listCommerceOrders,
  getCommerceOrderDetails,
  updateCommerceOrderStatus,
  placeCommerceOrder,
  getCommerceOrderSettings,
  upsertCommerceOrderSettings,
  updateCommerceOrderCharges,
  deleteCommerceOrder,
}
