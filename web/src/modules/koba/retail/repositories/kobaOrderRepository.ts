import { supabase } from 'src/boot/supabase'

export type KobaOrderStatus =
  | 'pending'
  | 'confirmed'
  | 'processing'
  | 'shipped'
  | 'delivered'
  | 'cancelled'

export interface KobaOrder {
  id: number
  tenant_id: number
  customer_group_id: number | null
  user_name: string | null
  shipping_name: string | null
  shipping_phone: string | null
  shipping_district: string | null
  shipping_thana: string | null
  shipping_address: string | null
  free_delivery: boolean
  subtotal_gbp: number | null
  total_commission: number | null
  extra_profit_user: number | null
  extra_profit_company: number | null
  delivery_adjustment: number | null
  cod_charge: number | null
  packing_charge: number | null
  invoice_charge: number | null
  net_order_commission: number | null
  item_count: number
  status: KobaOrderStatus
  note: string | null
  created_at: string
  updated_at: string
}

export interface KobaOrderItem {
  id: number
  order_id: number
  product_id: string
  product_code: string | null
  barcode: string | null
  name: string
  brand: string | null
  image_url: string | null
  case_size: number
  unit_price_gbp: number | null
  custom_price_gbp: number | null
  commission: number | null
  commission_percentage: number | null
  quantity: number
  confirmed_quantity: number | null
  delivered_quantity: number
  created_at: string
  updated_at: string
}

export interface KobaOrderListPage {
  data: KobaOrder[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export interface PlaceOrderInput {
  tenant_id: number
  customer_group_id: number | null
  shipping_name: string | null
  shipping_phone: string | null
  shipping_district: string | null
  shipping_thana: string | null
  shipping_address: string | null
  free_delivery: boolean
  extra_profit_user?: number | undefined
  extra_profit_company?: number | undefined
  delivery_adjustment?: number | undefined
  cod_charge?: number | undefined
  packing_charge?: number | undefined
  invoice_charge?: number | undefined
  net_order_commission?: number | undefined
}

export interface PlaceOrderResult {
  order_id: number
  customer_group_id: number | null
  item_count: number
  subtotal_gbp: number
  total_commission: number
  status: KobaOrderStatus
}

const placeOrder = async (
  payload: PlaceOrderInput
): Promise<PlaceOrderResult> => {
  const { data, error } = await supabase.rpc('place_koba_order', {
    p_tenant_id: payload.tenant_id,
    p_customer_group_id: payload.customer_group_id,
    p_shipping_name: payload.shipping_name,
    p_shipping_phone: payload.shipping_phone,
    p_shipping_district: payload.shipping_district,
    p_shipping_thana: payload.shipping_thana,
    p_shipping_address: payload.shipping_address,
    p_free_delivery: payload.free_delivery,
    p_extra_profit_user: payload.extra_profit_user ?? 0,
    p_extra_profit_company: payload.extra_profit_company ?? 0,
    p_delivery_adjustment: payload.delivery_adjustment ?? 0,
    p_cod_charge: payload.cod_charge ?? 0,
    p_packing_charge: payload.packing_charge ?? 0,
    p_invoice_charge: payload.invoice_charge ?? 0,
    p_net_order_commission: payload.net_order_commission ?? 0,
  })

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Failed to place Koba order.')
  }

  return data as PlaceOrderResult
}

const listOrders = async (
  tenantId: number,
  customerGroupId: number | null = null,
  page: number = 1,
  pageSize: number = 20,
  status: KobaOrderStatus | null = null
): Promise<KobaOrderListPage> => {
  const { data, error } = await supabase.rpc('list_koba_orders', {
    p_tenant_id: tenantId,
    p_customer_group_id: customerGroupId,
    p_page: page,
    p_page_size: pageSize,
    p_status: status,
  })

  if (error) {
    throw error
  }

  return data as KobaOrderListPage
}

const getOrderById = async (orderId: number): Promise<KobaOrder> => {
  const { data, error } = await supabase
    .from('koba_orders')
    .select('*')
    .eq('id', orderId)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Koba Order not found.')
  }

  return data as KobaOrder
}

const getOrderItems = async (
  orderId: number
): Promise<KobaOrderItem[]> => {
  const { data, error } = await supabase
    .from('koba_order_items')
    .select('*')
    .eq('order_id', orderId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as KobaOrderItem[] | null) ?? []
}

const updateOrderStatus = async (
  orderId: number,
  status: KobaOrderStatus
): Promise<Pick<KobaOrder, 'id' | 'status' | 'updated_at'>> => {
  const { data, error } = await supabase
    .from('koba_orders')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', orderId)
    .select('id, status, updated_at')
    .single()

  if (error) throw error
  if (!data) throw new Error('Failed to update order status.')

  return data
}

const updateItemConfirmedQty = async (
  itemId: number,
  confirmedQuantity: number
): Promise<Pick<KobaOrderItem, 'id' | 'confirmed_quantity' | 'updated_at'>> => {
  const { data, error } = await supabase
    .from('koba_order_items')
    .update({
      confirmed_quantity: confirmedQuantity,
      updated_at: new Date().toISOString(),
    })
    .eq('id', itemId)
    .select('id, confirmed_quantity, updated_at')
    .single()

  if (error) throw error
  if (!data) throw new Error('Failed to update confirmed quantity.')

  return data
}

const updateItemDeliveredQty = async (
  itemId: number,
  deliveredQuantity: number
): Promise<Pick<KobaOrderItem, 'id' | 'delivered_quantity' | 'updated_at'>> => {
  const { data, error } = await supabase
    .from('koba_order_items')
    .update({
      delivered_quantity: deliveredQuantity,
      updated_at: new Date().toISOString(),
    })
    .eq('id', itemId)
    .select('id, delivered_quantity, updated_at')
    .single()

  if (error) throw error
  if (!data) throw new Error('Failed to update delivered quantity.')

  return data
}

const softDeleteOrder = async (
  orderId: number
): Promise<Pick<KobaOrder, 'id' | 'status' | 'updated_at'>> => {
  // Delete order items first to handle foreign key constraints cleanly
  await supabase
    .from('koba_order_items')
    .delete()
    .eq('order_id', orderId)

  const { data, error } = await supabase
    .from('koba_orders')
    .delete()
    .eq('id', orderId)
    .select('id')
    .single()

  if (error) throw error
  if (!data) throw new Error('Failed to delete order.')

  return {
    id: data.id,
    status: 'cancelled',
    updated_at: new Date().toISOString(),
  }
}

export const kobaOrderRepository = {
  placeOrder,
  listOrders,
  getOrderById,
  getOrderItems,
  updateOrderStatus,
  updateItemConfirmedQty,
  updateItemDeliveredQty,
  softDeleteOrder,
}