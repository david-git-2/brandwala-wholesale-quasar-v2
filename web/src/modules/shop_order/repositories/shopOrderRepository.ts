import { supabase } from 'src/boot/supabase'
import type { Shop, CreateShopPayload, UpdateShopPayload, ShopOrder, ShopOrderItem } from '../types'

const listShops = async (
  tenantId: number,
  opts: { limit?: number; offset?: number; search?: string | null; active?: boolean | null } = {},
): Promise<Shop[]> => {
  const { data, error } = await supabase.rpc('list_shops', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 200,
    p_offset: opts.offset ?? 0,
    p_search: opts.search ?? null,
    p_active: opts.active ?? null,
  })

  if (error) {
    throw error
  }

  return (data as Shop[] | null) ?? []
}

const upsertShop = async (payload: CreateShopPayload | UpdateShopPayload): Promise<Shop> => {
  const isEdit = 'id' in payload && typeof (payload as UpdateShopPayload).id === 'number'

  const { data, error } = await supabase.rpc('upsert_shop', {
    p_tenant_id:           payload.tenant_id,
    p_name:                payload.name.trim(),
    p_slug:                payload.slug.trim().toLowerCase(),
    p_order_mode:          payload.order_mode,
    p_is_negotiable:       payload.is_negotiable,
    p_show_stock_quantity: payload.show_stock_quantity,
    p_is_active:           payload.is_active,
    // create-only
    p_shop_type:           isEdit ? null : (payload as CreateShopPayload).shop_type,
    p_vendor_code:         isEdit ? null : ((payload as CreateShopPayload).vendor_code?.trim() || null),
    // optional
    p_id:                  isEdit ? (payload as UpdateShopPayload).id : null,
    p_default_currency_id: payload.default_currency_id ?? null,
    p_global_stock_type_id: payload.global_stock_type_id ?? null,
  })

  if (error) {
    throw error
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Shop was not saved.')
  }

  return (Array.isArray(data) ? data[0] : data) as Shop
}

const browseShopCatalog = async (
  shopSlug: string,
  opts: {
    search?: string | null
    category?: string | null
    brand?: string | null
    limit?: number
    offset?: number
  } = {},
): Promise<any> => {
  const { data, error } = await supabase.rpc('browse_shop_catalog', {
    p_shop_slug: shopSlug,
    p_search: opts.search ?? null,
    p_category: opts.category ?? null,
    p_brand: opts.brand ?? null,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
  })

  if (error) {
    throw error
  }

  return data
}

// ---- Order Management RPCs (P7) ---------------------------------------

const submitShopOrderFromCart = async (
  cartId: number,
  recipientName: string,
  recipientPhone: string,
  shippingAddress: string,
  billingProfileId: number | null,
): Promise<{ order_id: number; order_no: string; status: string }> => {
  const { data, error } = await supabase.rpc('submit_shop_order_from_cart', {
    p_cart_id: cartId,
    p_recipient_name: recipientName,
    p_recipient_phone: recipientPhone,
    p_shipping_address: shippingAddress,
    p_billing_profile_id: billingProfileId || null,
  })

  if (error) throw error
  return data as { order_id: number; order_no: string; status: string }
}

const staffPriceShopOrder = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_price_shop_order', {
    p_order_id: orderId,
    p_items: items,
  })
  if (error) throw error
}

const customerCounterOffer = async (
  orderId: number,
  items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('customer_counter_offer', {
    p_order_id: orderId,
    p_items: items,
  })
  if (error) throw error
}

const staffCounterOffer = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_counter_offer', {
    p_order_id: orderId,
    p_items: items,
  })
  if (error) throw error
}

const confirmShopOrder = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('confirm_shop_order', {
    p_order_id: orderId,
  })
  if (error) throw error
}

const listShopOrdersForCustomer = async (
  shopId: number,
  opts: { limit?: number; offset?: number } = {},
): Promise<ShopOrder[]> => {
  const { data, error } = await supabase.rpc('list_shop_orders_for_customer', {
    p_shop_id: shopId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
  })
  if (error) throw error
  return (data as ShopOrder[] | null) ?? []
}

const listShopOrdersForStaff = async (
  tenantId: number,
  opts: { limit?: number; offset?: number; search?: string | null; status?: string | null } = {},
): Promise<ShopOrder[]> => {
  const { data, error } = await supabase.rpc('list_shop_orders_for_staff', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
    p_search: opts.search ?? null,
    p_status: opts.status ?? null,
  })
  if (error) throw error
  return (data as ShopOrder[] | null) ?? []
}

const getShopOrderById = async (orderId: number): Promise<{ order: ShopOrder; items: ShopOrderItem[] }> => {
  const { data: order, error: orderErr } = await supabase
    .from('shop_orders')
    .select('*')
    .eq('id', orderId)
    .single()

  if (orderErr) throw orderErr

  const { data: items, error: itemsErr } = await supabase
    .from('shop_order_items')
    .select('*')
    .eq('order_id', orderId)

  if (itemsErr) throw itemsErr

  return {
    order: order as ShopOrder,
    items: (items as ShopOrderItem[] | null) ?? [],
  }
}

const placeShopOrderForProcurement = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('place_shop_order_for_procurement', {
    p_order_id: orderId,
  })
  if (error) throw error
}

const fulfillShopOrderToInvoice = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('fulfill_shop_order_to_invoice', {
    p_order_id: orderId,
  })
  if (error) throw error
}

export const shopOrderRepository = {
  listShops,
  upsertShop,
  browseShopCatalog,
  submitShopOrderFromCart,
  staffPriceShopOrder,
  customerCounterOffer,
  staffCounterOffer,
  confirmShopOrder,
  listShopOrdersForCustomer,
  listShopOrdersForStaff,
  getShopOrderById,
  placeShopOrderForProcurement,
  fulfillShopOrderToInvoice,
}

