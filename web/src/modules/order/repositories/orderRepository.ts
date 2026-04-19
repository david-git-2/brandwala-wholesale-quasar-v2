import { supabase } from 'src/boot/supabase'

import type {
  Order,
  OrderCreateInput,
  OrderDeleteInput,
  OrderGetByIdInput,
  OrderItem,
  OrderItemBulkUpdateInput,
  OrderItemCreateInput,
  OrderItemDeleteInput,
  OrderItemUpdateInput,
  OrderListPage,
  OrderListInput,
  OrderUpdateInput,
  OrderWithItems,
} from '../types'

type OrderProductSnapshot = {
  id: number
  barcode: string | null
  product_code: string | null
  product_weight: number | null
  package_weight: number | null
}

type OrderListRow = Order & {
  customer_groups?:
    | {
      name: string | null
    }
    | Array<{
      name: string | null
    }>
    | null
}

const ORDER_FIELDS = [
  'id',
  'name',
  'customer_group_id',
  'can_see_price',
  'accent_color',
  'cargo_rate',
  'conversion_rate',
  'profit_rate',
  'negotiate',
  'status',
  'store_id',
  'shipment_id',
  'created_at',
  'updated_at',
] as const

const ORDER_ITEM_FIELDS = [
  'id',
  'order_id',
  'shipment_id',
  'name',
  'image_url',
  'barcode',
  'product_code',
  'price_gbp',
  'cost_gbp',
  'cost_bdt',
  'first_offer_bdt',
  'customer_offer_bdt',
  'final_offer_bdt',
  'product_weight',
  'package_weight',
  'minimum_quantity',
  'product_id',
  'ordered_quantity',
  'delivered_quantity',
  'returned_quantity',
  'created_at',
  'updated_at',
] as const

const pickFields = (requested: string[] | undefined, allowed: readonly string[]) => {
  if (!requested || !requested.length) {
    return '*'
  }

  const safe = requested.map((value) => value.trim()).filter((value) => allowed.includes(value))

  return safe.length ? safe.join(',') : '*'
}

const listOrders = async (payload: OrderListInput = {}): Promise<OrderListPage> => {
  const orderSelect = pickFields(payload.fields, ORDER_FIELDS)
  const pageSize = Math.max(1, payload.page_size ?? payload.limit ?? 20)
  const page = Math.max(1, payload.page ?? 1)
  const offset = payload.offset ?? (page - 1) * pageSize
  const from = Math.max(0, offset)
  const to = from + pageSize - 1

  const relationSelect = `${orderSelect},customer_groups(name)`

  let query = supabase
    .from('orders')
    .select(relationSelect, { count: 'exact' })
    .order('id', { ascending: false })

  if (payload.customer_group_id != null) {
    query = query.eq('customer_group_id', payload.customer_group_id)
  }

  if (payload.store_id != null) {
    query = query.eq('store_id', payload.store_id)
  }

  if (payload.shipment_id != null) {
    query = query.eq('shipment_id', payload.shipment_id)
  }

  if (payload.status != null) {
    query = query.eq('status', payload.status)
  }

  query = query.range(from, to)

  const { data, error, count } = await query

  if (error) {
    throw error
  }

  const rawRows = (data as unknown as OrderListRow[] | null) ?? []
  const rows = rawRows.map((row) => {
    const relation = row.customer_groups
    const customerGroupName = Array.isArray(relation)
      ? (relation[0]?.name ?? null)
      : (relation?.name ?? null)

    const { customer_groups, ...rest } = row
    void customer_groups

    return {
      ...(rest as Order),
      customer_group_name: customerGroupName,
    }
  })
  const total = count ?? 0

  return {
    data: rows,
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createOrder = async (payload: OrderCreateInput): Promise<Order> => {
  const createPayload = {
    ...payload,
    shipment_id: payload.shipment_id ?? null,
  }

  const { data, error } = await supabase
    .from('orders')
    .insert([createPayload])
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Order was not created.')
  }

  return data as Order
}

const getOrderById = async (payload: OrderGetByIdInput): Promise<OrderWithItems> => {
  const orderSelect = pickFields(payload.order_fields, ORDER_FIELDS)
  const itemSelect = pickFields(payload.item_fields, ORDER_ITEM_FIELDS)
  const select = `${orderSelect},order_items(${itemSelect})`

  const { data, error } = await supabase
    .from('orders')
    .select(select)
    .eq('id', payload.id)
    .order('id', { ascending: true, foreignTable: 'order_items' })
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Order not found.')
  }

  return data as unknown as OrderWithItems
}

const updateOrder = async (payload: OrderUpdateInput): Promise<Order> => {
  const { data, error } = await supabase
    .from('orders')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Order was not updated.')
  }

  return data as Order
}

const updateOrderItem = async (payload: OrderItemUpdateInput): Promise<OrderItem> => {
  const { data, error } = await supabase
    .from('order_items')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Order item was not updated.')
  }

  return data as OrderItem
}

const createOrderItems = async (payload: OrderItemCreateInput[]): Promise<OrderItem[]> => {
  if (!payload.length) {
    return []
  }

  const createPayload = payload.map((item) => ({
    ...item,
    shipment_id: item.shipment_id ?? null,
  }))

  const { data, error } = await supabase
    .from('order_items')
    .insert(createPayload)
    .select('*')

  if (error) {
    throw error
  }

  return (data as OrderItem[] | null) ?? []
}

const bulkUpdateOrderItems = async (
  payload: OrderItemBulkUpdateInput,
): Promise<OrderItem[]> => {
  const normalizeId = (value: unknown): number | null => {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }

    if (typeof value === 'string' && value.trim() !== '') {
      const parsed = Number(value)
      return Number.isFinite(parsed) ? parsed : null
    }

    return null
  }

  const sanitizedPayload = payload
    .map((entry) => {
      const sanitized = Object.fromEntries(
        Object.entries(entry).filter(([, value]) => value !== undefined),
      ) as Record<string, unknown>

      const normalizedId = normalizeId(sanitized.id)
      if (normalizedId == null) {
        return null
      }

      sanitized.id = normalizedId
      return sanitized
    })
    .filter((entry): entry is Record<string, unknown> => entry != null)

  if (!sanitizedPayload.length) {
    return []
  }

  const { data, error } = await supabase.rpc('bulk_update_order_items' as never, {
    p_items: sanitizedPayload,
  } as never)

  if (!error) {
    return (data as OrderItem[] | null) ?? []
  }

  const updatedRows: OrderItem[] = []

  for (const entry of sanitizedPayload) {
    const { id, ...patch } = entry

    if (!Object.keys(patch).length) {
      continue
    }

    const { data: rowData, error: rowError } = await supabase
      .from('order_items')
      .update(patch)
      .eq('id', id as number)
      .select('*')
      .single()

    if (rowError) {
      throw rowError
    }

    if (rowData) {
      updatedRows.push(rowData as OrderItem)
    }
  }

  return updatedRows
}

const deleteOrder = async (payload: OrderDeleteInput): Promise<void> => {
  const { error } = await supabase.from('orders').delete().eq('id', payload.id)

  if (error) {
    throw error
  }
}

const deleteOrderItem = async (payload: OrderItemDeleteInput): Promise<void> => {
  const { error } = await supabase.from('order_items').delete().eq('id', payload.id)

  if (error) {
    throw error
  }
}

const getOrderProductSnapshots = async (productIds: number[]): Promise<OrderProductSnapshot[]> => {
  const uniqueIds = Array.from(new Set(productIds)).filter((id) => Number.isFinite(id))
  if (!uniqueIds.length) {
    return []
  }

  const { data, error } = await supabase
    .from('products')
    .select('id,barcode,product_code,product_weight,package_weight')
    .in('id', uniqueIds)

  if (error) {
    throw error
  }

  return (data as OrderProductSnapshot[] | null) ?? []
}

export const orderRepository = {
  listOrders,
  createOrder,
  getOrderById,
  updateOrder,
  createOrderItems,
  bulkUpdateOrderItems,
  updateOrderItem,
  deleteOrder,
  deleteOrderItem,
  getOrderProductSnapshots,
}
