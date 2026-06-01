import { supabase } from 'src/boot/supabase'
import type { CommerceOrder, CommerceOrderItem, CommerceOrderStatus, CommerceOrderSettings } from '../types'

const listCommerceOrders = async (tenantId: number, customerGroupId?: number | null): Promise<CommerceOrder[]> => {
  let query = supabase
    .from('commerce_orders')
    .select('*')
    .eq('tenant_id', tenantId)

  if (customerGroupId != null) {
    query = query.eq('customer_group_id', customerGroupId)
  }

  const { data, error } = await query.order('id', { ascending: false })

  if (error) throw error
  return data || []
}

const getCommerceOrderDetails = async (
  orderId: number,
): Promise<{ order: CommerceOrder; items: CommerceOrderItem[] }> => {
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

  return {
    order,
    items: items || [],
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

export const commerceOrderRepository = {
  listCommerceOrders,
  getCommerceOrderDetails,
  updateCommerceOrderStatus,
  placeCommerceOrder,
  getCommerceOrderSettings,
  upsertCommerceOrderSettings,
  updateCommerceOrderCharges,
}
