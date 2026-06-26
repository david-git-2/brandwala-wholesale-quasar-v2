import { supabase } from 'src/boot/supabase'

const db = supabase as any

export interface GlobalStockType {
  id: number
  parent_tenant_id: number | null
  description: string
  is_sellable: boolean
  sort_order: number
  created_at: string
  updated_at: string
}

const listStockTypes = async (parentTenantId: number | null): Promise<GlobalStockType[]> => {
  // Return system-wide types (parent_tenant_id is null) plus tenant-specific ones
  const query = db
    .from('global_stock_types')
    .select('*')

  if (parentTenantId) {
    query.or(`parent_tenant_id.is.null,parent_tenant_id.eq.${parentTenantId}`)
  } else {
    query.is('parent_tenant_id', null)
  }

  const { data, error } = await query.order('sort_order', { ascending: true })

  if (error) throw error
  return (data as GlobalStockType[] | null) ?? []
}

const createStockType = async (
  parentTenantId: number | null,
  payload: {
    description: string
    is_sellable: boolean
    sort_order: number
  },
): Promise<GlobalStockType> => {
  const { data, error } = await db
    .from('global_stock_types')
    .insert([
      {
        parent_tenant_id: parentTenantId,
        description: payload.description.trim(),
        is_sellable: payload.is_sellable,
        sort_order: payload.sort_order,
      },
    ])
    .select()
    .single()

  if (error) throw error
  return data as GlobalStockType
}

const updateStockType = async (
  id: number,
  payload: {
    description: string
    is_sellable: boolean
    sort_order: number
  },
): Promise<GlobalStockType> => {
  const { data, error } = await db
    .from('global_stock_types')
    .update({
      description: payload.description.trim(),
      is_sellable: payload.is_sellable,
      sort_order: payload.sort_order,
    })
    .eq('id', id)
    .select()
    .single()

  if (error) throw error
  return data as GlobalStockType
}

const deleteStockType = async (id: number): Promise<void> => {
  const { error } = await db.from('global_stock_types').delete().eq('id', id)
  if (error) throw error
}

const checkStockTypeReferences = async (stockTypeId: number): Promise<boolean> => {
  const { data, error } = await db
    .from('global_stocks')
    .select('id')
    .eq('stock_type_id', stockTypeId)
    .limit(1)

  if (error) throw error
  return (data && data.length > 0) || false
}

export const globalStockTypeRepository = {
  listStockTypes,
  createStockType,
  updateStockType,
  deleteStockType,
  checkStockTypeReferences,
}
