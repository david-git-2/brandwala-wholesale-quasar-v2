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
      product_id,
      tenant_id,
      customer_group_id,
      quantity,
      created_at,
      updated_at,
      product:products (
        name,
        image_url,
        minimum_order_quantity
      )
    `)
    .eq('tenant_id', tenantId)
    .eq('customer_group_id', customerGroupId)

  if (error) {
    throw error
  }

  const items = (data || []) as unknown as Array<{
    id: number
    product_id: number
    tenant_id: number
    customer_group_id: number
    quantity: number
    created_at: string
    updated_at: string
    product: {
      name: string
      image_url: string | null
      minimum_order_quantity: number | null
    } | null
  }>

  if (items.length === 0 || storeId == null) {
    return items.map((row) => ({
      id: row.id,
      product_id: row.product_id,
      tenant_id: row.tenant_id,
      customer_group_id: row.customer_group_id,
      quantity: row.quantity,
      created_at: row.created_at,
      updated_at: row.updated_at,
      name: row.product?.name ?? 'Unnamed product',
      image_url: row.product?.image_url ?? null,
      minimum_quantity: row.product?.minimum_order_quantity ?? 1,
      price_bdt: null,
      price_gbp: null,
      minimum_sell_price_bdt: null,
    }))
  }

  const productIds = items.map((item) => item.product_id)
  const { data: priceData, error: priceError } = await supabase
    .from('store_product_prices')
    .select('product_id, price_bdt, minimum_sell_price_bdt')
    .eq('store_id', storeId)
    .in('product_id', productIds)

  if (priceError) {
    throw priceError
  }

  const priceMap = new Map<number, { price_bdt: number; minimum_sell_price_bdt: number }>()
  if (priceData) {
    priceData.forEach((row) => {
      priceMap.set(row.product_id, {
        price_bdt: Number(row.price_bdt),
        minimum_sell_price_bdt: Number(row.minimum_sell_price_bdt),
      })
    })
  }

  return items.map((row) => {
    const prices = priceMap.get(row.product_id)
    return {
      id: row.id,
      product_id: row.product_id,
      tenant_id: row.tenant_id,
      customer_group_id: row.customer_group_id,
      quantity: row.quantity,
      created_at: row.created_at,
      updated_at: row.updated_at,
      name: row.product?.name ?? 'Unnamed product',
      image_url: row.product?.image_url ?? null,
      minimum_quantity: row.product?.minimum_order_quantity ?? 1,
      price_bdt: prices?.price_bdt ?? null,
      price_gbp: prices?.price_bdt ?? null,
      minimum_sell_price_bdt: prices?.minimum_sell_price_bdt ?? null,
    }
  })
}

const addToCommerceCart = async (payload: AddCommerceItemInput): Promise<CommerceCartItem> => {
  // Call the RPC that safely does insert-or-update without PGRST116 issues
  const { data: rpcData, error: rpcError } = await supabase.rpc('add_item_to_commerce_cart', {
    p_tenant_id: payload.tenant_id,
    p_customer_group_id: payload.customer_group_id,
    p_product_id: payload.product_id,
    p_quantity: payload.quantity,
  })

  if (rpcError) {
    throw rpcError
  }

  const rpcRow = rpcData as {
    id: number
    product_id: number
    tenant_id: number
    customer_group_id: number
    quantity: number
    created_at: string
    updated_at: string
  }

  // Fetch product details separately
  const { data: productData } = await supabase
    .from('products')
    .select('name, image_url, minimum_order_quantity')
    .eq('id', payload.product_id)
    .maybeSingle()

  // Fetch store price if a store is selected
  let price_bdt: number | null = null
  let minimum_sell_price_bdt: number | null = null

  if (payload.store_id != null) {
    const { data: priceData } = await supabase
      .from('store_product_prices')
      .select('price_bdt, minimum_sell_price_bdt')
      .eq('store_id', payload.store_id)
      .eq('product_id', payload.product_id)
      .maybeSingle()

    if (priceData) {
      price_bdt = Number(priceData.price_bdt)
      minimum_sell_price_bdt = Number(priceData.minimum_sell_price_bdt)
    }
  }

  return {
    id: rpcRow.id,
    product_id: rpcRow.product_id,
    tenant_id: rpcRow.tenant_id,
    customer_group_id: rpcRow.customer_group_id,
    quantity: rpcRow.quantity,
    created_at: rpcRow.created_at,
    updated_at: rpcRow.updated_at,
    name: productData?.name ?? 'Unnamed product',
    image_url: productData?.image_url ?? null,
    minimum_quantity: productData?.minimum_order_quantity ?? 1,
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
