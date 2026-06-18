import { supabase } from 'src/boot/supabase'
import type { AddCommerceItemInput, CommerceCartItem } from '../types'

const listCartItems = async (
  tenantId: number,
  customerGroupId: number,
  storeId: number | null,
): Promise<CommerceCartItem[]> => {
  const { data, error } = await supabase
    .from('commerce_cart')
    .select(`
      id,
      global_stock_id,
      inventory_item_id,
      tenant_id,
      customer_group_id,
      quantity,
      created_at,
      updated_at,
      global_stock:global_stocks (
        name,
        image_url,
        product_id,
        product:products (
          minimum_order_quantity
        )
      )
    `)
    .eq('tenant_id', tenantId)
    .eq('customer_group_id', customerGroupId)

  if (error) {
    throw error
  }

  const items = (data || []) as unknown as Array<{
    id: number
    global_stock_id: number | null
    inventory_item_id: number | null
    tenant_id: number
    customer_group_id: number
    quantity: number
    created_at: string
    updated_at: string
    global_stock: {
      name: string
      image_url: string | null
      product_id: number | null
      product: {
        minimum_order_quantity: number | null
      } | null
    } | null
  }>

  const stockIds = items
    .map((item) => item.global_stock_id)
    .filter((id): id is number => typeof id === 'number')

  if (items.length === 0 || storeId == null || stockIds.length === 0) {
    return items.map((row) => ({
      id: row.id,
      product_id: row.global_stock_id ?? row.inventory_item_id ?? 0,
      tenant_id: row.tenant_id,
      customer_group_id: row.customer_group_id,
      quantity: row.quantity,
      created_at: row.created_at,
      updated_at: row.updated_at,
      name: row.global_stock?.name ?? 'Unnamed batch',
      image_url: row.global_stock?.image_url ?? null,
      minimum_quantity: row.global_stock?.product?.minimum_order_quantity ?? 1,
      price_bdt: null,
      price_gbp: null,
      minimum_sell_price_bdt: null,
    }))
  }

  const { data: priceData, error: priceError } = await supabase
    .from('store_product_prices')
    .select('global_stock_id, inventory_item_id, price_bdt, minimum_sell_price_bdt')
    .eq('store_id', storeId)
    .in('global_stock_id', stockIds)

  if (priceError) {
    throw priceError
  }

  const priceMap = new Map<number, { price_bdt: number; minimum_sell_price_bdt: number }>()
  if (priceData) {
    priceData.forEach((row) => {
      const key = row.global_stock_id ?? row.inventory_item_id
      if (key != null) {
        priceMap.set(key, {
          price_bdt: Number(row.price_bdt),
          minimum_sell_price_bdt: Number(row.minimum_sell_price_bdt),
        })
      }
    })
  }

  return items.map((row) => {
    const stockId = row.global_stock_id ?? row.inventory_item_id ?? 0
    const prices = priceMap.get(stockId)
    return {
      id: row.id,
      product_id: stockId,
      tenant_id: row.tenant_id,
      customer_group_id: row.customer_group_id,
      quantity: row.quantity,
      created_at: row.created_at,
      updated_at: row.updated_at,
      name: row.global_stock?.name ?? 'Unnamed batch',
      image_url: row.global_stock?.image_url ?? null,
      minimum_quantity: row.global_stock?.product?.minimum_order_quantity ?? 1,
      price_bdt: prices?.price_bdt ?? null,
      price_gbp: prices?.price_bdt ?? null,
      minimum_sell_price_bdt: prices?.minimum_sell_price_bdt ?? null,
    }
  })
}

const addToCommerceCart = async (payload: AddCommerceItemInput): Promise<CommerceCartItem> => {
  const { data: rpcData, error: rpcError } = await supabase.rpc('add_item_to_commerce_cart', {
    p_tenant_id: payload.tenant_id,
    p_customer_group_id: payload.customer_group_id,
    p_global_stock_id: payload.product_id,
    p_quantity: payload.quantity,
  })

  if (rpcError) {
    throw rpcError
  }

  const rpcRow = rpcData as {
    id: number
    global_stock_id: number | null
    inventory_item_id: number | null
    tenant_id: number
    customer_group_id: number
    quantity: number
    created_at: string
    updated_at: string
  }

  const stockId = rpcRow.global_stock_id ?? rpcRow.inventory_item_id ?? payload.product_id

  const { data: itemData } = await supabase
    .from('global_stocks')
    .select(`
      name,
      image_url,
      product:products (
        minimum_order_quantity
      )
    `)
    .eq('id', stockId)
    .maybeSingle()

  let price_bdt: number | null = null
  let minimum_sell_price_bdt: number | null = null

  if (payload.store_id != null) {
    const { data: priceData } = await supabase
      .from('store_product_prices')
      .select('price_bdt, minimum_sell_price_bdt')
      .eq('store_id', payload.store_id)
      .eq('global_stock_id', stockId)
      .maybeSingle()

    if (priceData) {
      price_bdt = Number(priceData.price_bdt)
      minimum_sell_price_bdt = Number(priceData.minimum_sell_price_bdt)
    }
  }

  const productObj = Array.isArray(itemData?.product)
    ? itemData.product[0]
    : (itemData?.product as { minimum_order_quantity?: number | null } | null | undefined)

  return {
    id: rpcRow.id,
    product_id: stockId,
    tenant_id: rpcRow.tenant_id,
    customer_group_id: rpcRow.customer_group_id,
    quantity: rpcRow.quantity,
    created_at: rpcRow.created_at,
    updated_at: rpcRow.updated_at,
    name: itemData?.name ?? 'Unnamed batch',
    image_url: itemData?.image_url ?? null,
    minimum_quantity: productObj?.minimum_order_quantity ?? 1,
    price_bdt,
    price_gbp: price_bdt,
    minimum_sell_price_bdt,
  }
}

const updateCommerceCartQty = async (payload: { id: number; quantity: number }): Promise<{ id: number; quantity: number }> => {
  const { data, error } = await supabase
    .from('commerce_cart')
    .update({ quantity: payload.quantity })
    .eq('id', payload.id)
    .select('id, quantity')
    .single()

  if (error) {
    throw error
  }

  return data
}

const deleteCommerceCartItem = async (payload: { id: number }): Promise<void> => {
  const { error } = await supabase
    .from('commerce_cart')
    .delete()
    .eq('id', payload.id)

  if (error) {
    throw error
  }
}

const clearCommerceCart = async (payload: {
  tenant_id: number
  customer_group_id: number
}): Promise<void> => {
  const { error } = await supabase
    .from('commerce_cart')
    .delete()
    .eq('tenant_id', payload.tenant_id)
    .eq('customer_group_id', payload.customer_group_id)

  if (error) {
    throw error
  }
}

export const commerceCartRepository = {
  listCartItems,
  addToCommerceCart,
  updateCommerceCartQty,
  deleteCommerceCartItem,
  clearCommerceCart,
}
