import { supabase } from 'src/boot/supabase'

import type {
  AddItemToCartInput,
  AddItemToCartResult,
  Cart,
  CartCreateInput,
  CartDeleteInput,
  CartItem,
  CartItemCreateInput,
  CartItemDeleteInput,
  CartItemUpdateInput,
  CartUpdateInput,
  CartWithItemDetails,
  CartWithItems,
} from '../types'

const listCarts = async (): Promise<Cart[]> => {
  const { data, error } = await supabase
    .from('carts')
    .select('*')
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as Cart[] | null) ?? []
}

const findCart = async ({
  tenant_id,
  store_id,
  customer_group_id,
}: {
  tenant_id: number
  store_id?: number | null
  customer_group_id?: number | null
}): Promise<Cart | null> => {
  let query = supabase
    .from('carts')
    .select('*')
    .eq('tenant_id', tenant_id)

  query = store_id == null ? query.is('store_id', null) : query.eq('store_id', store_id)
  query =
    customer_group_id == null
      ? query.is('customer_group_id', null)
      : query.eq('customer_group_id', customer_group_id)

  const { data, error } = await query.order('id', { ascending: false }).limit(1).maybeSingle()

  if (error) {
    throw error
  }

  return (data as Cart | null) ?? null
}

const createCart = async (payload: CartCreateInput): Promise<Cart> => {
  const { data, error } = await supabase
    .from('carts')
    .insert([
      {
        tenant_id: payload.tenant_id,
        store_id: payload.store_id ?? null,
        customer_group_id: payload.customer_group_id ?? null,
        can_see_price: payload.can_see_price ?? false,
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart was not created.')
  }

  return data as Cart
}

const updateCart = async (payload: CartUpdateInput): Promise<Cart> => {
  const { id, ...rest } = payload
  const { data, error } = await supabase
    .from('carts')
    .update(rest)
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart was not updated.')
  }

  return data as Cart
}

const deleteCart = async (payload: CartDeleteInput): Promise<Cart> => {
  const { data, error } = await supabase
    .from('carts')
    .delete()
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart was not deleted.')
  }

  return data as Cart
}

const listCartItems = async (cartId: number): Promise<CartItem[]> => {
  const { data, error } = await supabase
    .from('cart_items')
    .select('*')
    .eq('cart_id', cartId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as CartItem[] | null) ?? []
}

const findCartItemByProduct = async ({
  cart_id,
  product_id,
}: {
  cart_id: number
  product_id: number
}): Promise<CartItem | null> => {
  const { data, error } = await supabase
    .from('cart_items')
    .select('*')
    .eq('cart_id', cart_id)
    .eq('product_id', product_id)
    .limit(1)
    .maybeSingle()

  if (error) {
    throw error
  }

  return (data as CartItem | null) ?? null
}

const createCartItem = async (payload: CartItemCreateInput): Promise<CartItem> => {
  const { data, error } = await supabase
    .from('cart_items')
    .insert([
      {
        cart_id: payload.cart_id,
        product_id: payload.product_id ?? null,
        name: payload.name,
        image_url: payload.image_url ?? null,
        price_gbp: payload.price_gbp ?? null,
        quantity: payload.quantity ?? 1,
        minimum_quantity: payload.minimum_quantity ?? 1,
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart item was not created.')
  }

  return data as CartItem
}

const updateCartItem = async (payload: CartItemUpdateInput): Promise<CartItem> => {
  const { id, ...rest } = payload
  const { data, error } = await supabase
    .from('cart_items')
    .update(rest)
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart item was not updated.')
  }

  return data as CartItem
}

const deleteCartItem = async (payload: CartItemDeleteInput): Promise<CartItem> => {
  const { data, error } = await supabase
    .from('cart_items')
    .delete()
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart item was not deleted.')
  }

  return data as CartItem
}

const deleteCartItemsBulk = async (itemIds: number[]): Promise<CartItem[]> => {
  if (!itemIds.length) {
    return []
  }

  const { data, error } = await supabase
    .from('cart_items')
    .delete()
    .in('id', itemIds)
    .select('*')

  if (error) {
    throw error
  }

  return (data as CartItem[] | null) ?? []
}

const getCart = async (cartId: number): Promise<CartWithItems> => {
  const { data, error } = await supabase.rpc('get_cart' as never, {
    p_cart_id: cartId,
  } as never)

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart was not found.')
  }

  return data as CartWithItems
}

const getCartDetails = async (cartId: number): Promise<CartWithItemDetails> => {
  const { data, error } = await supabase.rpc('get_cart_details' as never, {
    p_cart_id: cartId,
  } as never)

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart details were not found.')
  }

  return data as CartWithItemDetails
}

const addItemToCart = async (payload: AddItemToCartInput): Promise<AddItemToCartResult> => {
  const { data, error } = await supabase.rpc('add_item_to_cart' as never, {
    p_tenant_id: payload.tenant_id,
    p_store_id: payload.store_id ?? null,
    p_customer_group_id: payload.customer_group_id ?? null,
    p_can_see_price: payload.can_see_price ?? false,
    p_product_id: payload.product_id ?? null,
    p_name: payload.name,
    p_image_url: payload.image_url ?? null,
    p_price_gbp: payload.price_gbp ?? null,
    p_quantity: payload.quantity,
    p_minimum_quantity: payload.minimum_quantity ?? 1,
  } as never)

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Failed to add item to cart.')
  }

  return data as AddItemToCartResult
}

export const cartRepository = {
  listCarts,
  findCart,
  createCart,
  updateCart,
  deleteCart,
  listCartItems,
  findCartItemByProduct,
  createCartItem,
  updateCartItem,
  deleteCartItem,
  deleteCartItemsBulk,
  getCart,
  getCartDetails,
  addItemToCart,
}
