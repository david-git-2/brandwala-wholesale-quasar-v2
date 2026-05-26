import { supabase } from 'src/boot/supabase'

export interface KobaOrder {
  id: number
  tenant_id: number
  user_email: string
  user_name: string | null
  market_id: string | null
  shipping_name: string | null
  shipping_phone: string | null
  shipping_district: string | null
  shipping_thana: string | null
  shipping_address: string | null
  free_delivery: boolean
  subtotal_gbp: number | null
  total_commission: number | null
  item_count: number
  status: 'pending' | 'confirmed' | 'processing' | 'shipped' | 'delivered' | 'cancelled'
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
  commission: number | null
  commission_percentage: number | null
  quantity: number
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
  market_id: string | null
  shipping_name: string | null
  shipping_phone: string | null
  shipping_district: string | null
  shipping_thana: string | null
  shipping_address: string | null
  free_delivery: boolean
}

export interface PlaceOrderResult {
  order_id: number
  item_count: number
  subtotal_gbp: number
  total_commission: number
  status: string
}

const placeOrder = async (payload: PlaceOrderInput): Promise<PlaceOrderResult> => {
  const { data, error } = await supabase.rpc('place_koba_order', {
    p_tenant_id: payload.tenant_id,
    p_market_id: payload.market_id,
    p_shipping_name: payload.shipping_name,
    p_shipping_phone: payload.shipping_phone,
    p_shipping_district: payload.shipping_district,
    p_shipping_thana: payload.shipping_thana,
    p_shipping_address: payload.shipping_address,
    p_free_delivery: payload.free_delivery,
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
  marketId: string | null,
  page: number = 1,
  pageSize: number = 20,
  status: string | null = null,
): Promise<KobaOrderListPage> => {
  const { data, error } = await supabase.rpc('list_koba_orders', {
    p_tenant_id: tenantId,
    p_market_id: marketId,
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

const getOrderItems = async (orderId: number): Promise<KobaOrderItem[]> => {
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

export const kobaOrderRepository = {
  placeOrder,
  listOrders,
  getOrderById,
  getOrderItems,
}
