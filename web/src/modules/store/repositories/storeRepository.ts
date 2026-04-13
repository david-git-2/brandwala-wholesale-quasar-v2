import { supabase } from 'src/boot/supabase'

import type {
  Store,
  StoreAccess,
  StoreAccessCreateInput,
  StoreAccessDeleteInput,
  StoreProductsPage,
  StoreProductsQueryInput,
  StoreProductsRow,
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

const getStoreAccessAdmin = async (storeId: number): Promise<StoreAccess[]> => {
  const { data, error } = await supabase.rpc('get_store_access_admin' as never, {
    p_store_id: storeId,
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
  const { data, error } = await supabase.rpc('update_store_access' as never, {
    p_id: payload.id,
    p_status: payload.status,
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

const checkStoreAccess = async (storeId: number): Promise<boolean> => {
  const { data, error } = await supabase.rpc('check_store_access' as never, {
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

  const rows = (data as StoreProductsRow[] | null) ?? []

  return {
    items: rows.map((row) => row.product ?? {}),
    total: Number(rows[0]?.total_count ?? 0),
  }
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
  checkStoreAccess,
  listStoreProducts,
}
