import { supabase } from 'src/boot/supabase'

export interface KobaCart {
  id: number
  tenant_id: number
  market_id: string | null
  status: 'active' | 'ordered' | 'cleared'
  created_at: string
  updated_at: string
}

export interface KobaCartItem {
  id: number
  cart_id: number
  koba_product_id: string | null
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
  created_at: string
  updated_at: string
}

export interface KobaCartSnapshot {
  cart: KobaCart
  items: KobaCartItem[]
}

const getCart = async (tenantId: number, marketId: string | null): Promise<KobaCartSnapshot | null> => {
  const { data, error } = await supabase.rpc('get_koba_cart', {
    p_tenant_id: tenantId,
    p_market_id: marketId,
  })

  if (error) {
    // If no active cart is found or error occurs, return null or handle accordingly
    if (error.code === 'PGRST116') return null
    throw error
  }

  return data as KobaCartSnapshot | null
}

const createCart = async (tenantId: number, userEmail: string, marketId: string | null): Promise<KobaCart> => {
  const { data, error } = await supabase
    .from('koba_carts')
    .insert([
      {
        tenant_id: tenantId,
        user_email: userEmail,
        market_id: marketId,
        status: 'active',
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Koba Cart was not created.')
  }

  return data as KobaCart
}

const createCartItem = async (payload: Partial<KobaCartItem>): Promise<KobaCartItem> => {
  const { data, error } = await supabase
    .from('koba_cart_items')
    .insert([payload])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Koba Cart item was not created.')
  }

  return data as KobaCartItem
}

const updateCartItem = async (itemId: number, payload: Partial<KobaCartItem>): Promise<KobaCartItem> => {
  const { data, error } = await supabase
    .from('koba_cart_items')
    .update(payload)
    .eq('id', itemId)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Koba Cart item was not updated.')
  }

  return data as KobaCartItem
}

const deleteCartItem = async (itemId: number): Promise<KobaCartItem> => {
  const { data, error } = await supabase
    .from('koba_cart_items')
    .delete()
    .eq('id', itemId)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Koba Cart item was not deleted.')
  }

  return data as KobaCartItem
}

const clearCartItems = async (cartId: number): Promise<void> => {
  const { error } = await supabase
    .from('koba_cart_items')
    .delete()
    .eq('cart_id', cartId)

  if (error) {
    throw error
  }
}

export const kobaCartRepository = {
  getCart,
  createCart,
  createCartItem,
  updateCartItem,
  deleteCartItem,
  clearCartItems,
}
