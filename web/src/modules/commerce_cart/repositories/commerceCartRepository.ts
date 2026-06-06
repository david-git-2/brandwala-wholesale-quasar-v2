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
      inventory_item_id,
      tenant_id,
      customer_group_id,
      quantity,
      created_at,
      updated_at,
      inventory_item:inventory_items (
        name,
        image_url,
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
    inventory_item_id: number
    tenant_id: number
    customer_group_id: number
    quantity: number
    created_at: string
    updated_at: string
    inventory_item: {
      name: string
      image_url: string | null
      product: {
        minimum_order_quantity: number | null
      } | null
    } | null
  }>

  if (items.length === 0 || storeId == null) {
    return items.map((row) => ({
      id: row.id,
      product_id: row.inventory_item_id,
      tenant_id: row.tenant_id,
      customer_group_id: row.customer_group_id,
      quantity: row.quantity,
      created_at: row.created_at,
      updated_at: row.updated_at,
      name: row.inventory_item?.name ?? 'Unnamed batch',
      image_url: row.inventory_item?.image_url ?? null,
      minimum_quantity: row.inventory_item?.product?.minimum_order_quantity ?? 1,
      price_bdt: null,
      price_gbp: null,
      minimum_sell_price_bdt: null,
    }))
  }

  const inventoryItemIds = items.map((item) => item.inventory_item_id)
  const { data: priceData, error: priceError } = await supabase
    .from('store_product_prices')
    .select('inventory_item_id, price_bdt, minimum_sell_price_bdt')
    .eq('store_id', storeId)
    .in('inventory_item_id', inventoryItemIds)

  if (priceError) {
    throw priceError
  }

  const priceMap = new Map<number, { price_bdt: number; minimum_sell_price_bdt: number }>()
  if (priceData) {
    priceData.forEach((row) => {
      priceMap.set(row.inventory_item_id, {
        price_bdt: Number(row.price_bdt),
        minimum_sell_price_bdt: Number(row.minimum_sell_price_bdt),
      })
    })
  }

  return items.map((row) => {
    const prices = priceMap.get(row.inventory_item_id)
    return {
      id: row.id,
      product_id: row.inventory_item_id,
      tenant_id: row.tenant_id,
      customer_group_id: row.customer_group_id,
      quantity: row.quantity,
      created_at: row.created_at,
      updated_at: row.updated_at,
      name: row.inventory_item?.name ?? 'Unnamed batch',
      image_url: row.inventory_item?.image_url ?? null,
      minimum_quantity: row.inventory_item?.product?.minimum_order_quantity ?? 1,
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
    p_inventory_item_id: payload.product_id,
    p_quantity: payload.quantity,
  })

  if (rpcError) {
    throw rpcError
  }

  const rpcRow = rpcData as {
    id: number
    inventory_item_id: number
    tenant_id: number
    customer_group_id: number
    quantity: number
    created_at: string
    updated_at: string
  }

  // Fetch inventory item details separately
  const { data: itemData } = await supabase
    .from('inventory_items')
    .select(`
      name,
      image_url,
      product:products (
        minimum_order_quantity
      )
    `)
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
      .eq('inventory_item_id', payload.product_id)
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
    product_id: rpcRow.inventory_item_id,
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
