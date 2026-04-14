import { supabase } from 'src/boot/supabase'

import type {
  Store,
  StoreAccess,
  StoreAccessCreateInput,
  StoreAccessDeleteInput,
  StoreCart,
  StoreCartCreateInput,
  StoreCartDeleteInput,
  StoreCartDetailedPayload,
  StoreCartItem,
  StoreCartItemCreateInput,
  StoreCartItemDeleteInput,
  StoreCartItemUpdateInput,
  StoreCartPayload,
  StoreCartUpdateInput,
  StoreProductsPage,
  StoreProductsQueryInput,
  StoreAccessUpdateInput,
  StoreCreateInput,
  StoreDeleteInput,
  StoreUpdateInput,
} from '../types'

const getStoresAdmin = async (tenantId: number): Promise<Store[]> => {
  const { data, error } = await supabase.rpc('get_stores_admin' as never, {
    p_tenant_id: tenantId,
  } as never)

  if (error) {
    throw error
  }

  return (data as Store[] | null) ?? []
}

const createStore = async (payload: StoreCreateInput): Promise<Store> => {
  const { data, error } = await supabase.rpc('create_store' as never, {
    p_name: payload.name,
    p_vendor_code: payload.vendor_code,
    p_tenant_id: payload.tenant_id,
  } as never)

  if (error) {
    throw error
  }

  const row = Array.isArray(data) ? data[0] : data

  if (!row) {
    throw new Error('Store was not created.')
  }

  return row as Store
}

const updateStore = async (payload: StoreUpdateInput): Promise<Store> => {
  const { data, error } = await supabase.rpc('update_store' as never, {
    p_id: payload.id,
    p_name: payload.name,
    p_vendor_code: payload.vendor_code,
  } as never)

  if (error) {
    throw error
  }

  const row = Array.isArray(data) ? data[0] : data

  if (!row) {
    throw new Error('Store was not updated.')
  }

  return row as Store
}

const deleteStore = async (payload: StoreDeleteInput): Promise<void> => {
  const { error } = await supabase.rpc('delete_store' as never, {
    p_id: payload.id,
  } as never)

  if (error) {
    throw error
  }
}

const getStoreAccessAdmin = async (storeId?: number | null): Promise<StoreAccess[]> => {
  const { data, error } = await supabase.rpc('get_store_access_admin' as never, {
    p_store_id: storeId ?? null,
  } as never)

  if (error) {
    throw error
  }

  return (data as StoreAccess[] | null) ?? []
}

const createStoreAccess = async (
  payload: StoreAccessCreateInput,
): Promise<StoreAccess> => {
  const { data, error } = await supabase.rpc('create_store_access' as never, {
    p_store_id: payload.store_id,
    p_customer_group_id: payload.customer_group_id,
    p_status: payload.status ?? true,
    p_see_price: payload.see_price ?? false,
  } as never)

  if (error) {
    throw error
  }

  const row = Array.isArray(data) ? data[0] : data

  if (!row) {
    throw new Error('Store access was not created.')
  }

  return row as StoreAccess
}

const updateStoreAccess = async (
  payload: StoreAccessUpdateInput,
): Promise<StoreAccess> => {
  const { data, error } = await supabase.rpc('update_store_access_fields' as never, {
    p_id: payload.id,
    p_status: payload.status ?? null,
    p_see_price: payload.see_price ?? null,
  } as never)

  if (error) {
    throw error
  }

  const row = Array.isArray(data) ? data[0] : data

  if (!row) {
    throw new Error('Store access was not updated.')
  }

  return row as StoreAccess
}

const deleteStoreAccess = async (payload: StoreAccessDeleteInput): Promise<void> => {
  const { error } = await supabase.rpc('delete_store_access' as never, {
    p_id: payload.id,
  } as never)

  if (error) {
    throw error
  }
}

const getStoresForCustomer = async (): Promise<Store[]> => {
  const { data, error } = await supabase.rpc('get_stores_for_customer' as never)

  if (error) {
    throw error
  }

  return (data as Store[] | null) ?? []
}

const getStoreProductBrands = async (storeId: number): Promise<string[]> => {
  const { data, error } = await supabase.rpc('get_store_product_brands' as never, {
    p_store_id: storeId,
  } as never)

  if (error) {
    throw error
  }

  const rows = (data as Array<{ brand: string | null }> | null) ?? []
  return rows.map((row) => row.brand?.trim() ?? '').filter((item) => item.length > 0)
}

const getStoreProductCategories = async (storeId: number): Promise<string[]> => {
  const { data, error } = await supabase.rpc('get_store_product_categories' as never, {
    p_store_id: storeId,
  } as never)

  if (error) {
    throw error
  }

  const rows = (data as Array<{ category: string | null }> | null) ?? []
  return rows.map((row) => row.category?.trim() ?? '').filter((item) => item.length > 0)
}

const checkStoreAccess = async (storeId: number): Promise<boolean> => {
  const { data, error } = await supabase.rpc('check_store_access' as never, {
    p_store_id: storeId,
  } as never)

  if (error) {
    throw error
  }

  return Boolean(data)
}

const checkStorePriceAccess = async (storeId: number): Promise<boolean> => {
  const { data, error } = await supabase.rpc('check_store_price_access' as never, {
    p_store_id: storeId,
  } as never)

  if (error) {
    throw error
  }

  return Boolean(data)
}

const listStoreProducts = async (
  payload: StoreProductsQueryInput,
): Promise<StoreProductsPage> => {
  const { data, error } = await supabase.rpc('list_store_products' as never, {
    p_store_id: payload.store_id,
    p_fields: payload.fields ?? null,
    p_search: payload.search ?? null,
    p_category: payload.category ?? null,
    p_brand: payload.brand ?? null,
    p_sort_by: payload.sort_by ?? 'id',
    p_sort_dir: payload.sort_dir ?? 'asc',
    p_limit: payload.limit ?? 20,
    p_offset: payload.offset ?? 0,
  } as never)

  if (error) {
    throw error
  }

  const response = (data as StoreProductsPage | null) ?? null

  if (!response) {
    const fallbackLimit = payload.limit ?? 20
    const fallbackOffset = payload.offset ?? 0

    return {
      data: [],
      meta: {
        store_id: payload.store_id,
        limit: fallbackLimit,
        offset: fallbackOffset,
        current_page: Math.floor(fallbackOffset / fallbackLimit) + 1,
        sort_by: payload.sort_by ?? 'id',
        sort_dir: payload.sort_dir ?? 'asc',
        total: 0,
        can_see_price: false,
      },
    }
  }

  return response
}

const getCart = async (cartId: number): Promise<StoreCartPayload> => {
  const { data, error } = await supabase.rpc('get_cart' as never, {
    p_cart_id: cartId,
  } as never)

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart was not found.')
  }

  return data as StoreCartPayload
}

const getCartDetails = async (cartId: number): Promise<StoreCartDetailedPayload> => {
  const { data, error } = await supabase.rpc('get_cart_details' as never, {
    p_cart_id: cartId,
  } as never)

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Cart details were not found.')
  }

  return data as StoreCartDetailedPayload
}

const createCart = async (payload: StoreCartCreateInput): Promise<StoreCart> => {
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

  return data as StoreCart
}

const updateCart = async (payload: StoreCartUpdateInput): Promise<StoreCart> => {
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

  return data as StoreCart
}

const deleteCart = async (payload: StoreCartDeleteInput): Promise<StoreCart> => {
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

  return data as StoreCart
}

const createCartItem = async (
  payload: StoreCartItemCreateInput,
): Promise<StoreCartItem> => {
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

  return data as StoreCartItem
}

const updateCartItem = async (
  payload: StoreCartItemUpdateInput,
): Promise<StoreCartItem> => {
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

  return data as StoreCartItem
}

const deleteCartItem = async (
  payload: StoreCartItemDeleteInput,
): Promise<StoreCartItem> => {
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

  return data as StoreCartItem
}

export const storeRepository = {
  getStoresAdmin,
  createStore,
  updateStore,
  deleteStore,
  getStoreAccessAdmin,
  createStoreAccess,
  updateStoreAccess,
  deleteStoreAccess,
  getStoresForCustomer,
  getStoreProductBrands,
  getStoreProductCategories,
  checkStoreAccess,
  checkStorePriceAccess,
  listStoreProducts,
  getCart,
  getCartDetails,
  createCart,
  updateCart,
  deleteCart,
  createCartItem,
  updateCartItem,
  deleteCartItem,
}
