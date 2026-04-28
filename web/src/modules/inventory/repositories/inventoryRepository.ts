import { supabase } from 'src/boot/supabase'

import type {
  CreateInventoryItemInput,
  CreateInventoryMovementInput,
  CreateInventoryStockInput,
  DeleteInventoryItemInput,
  DeleteInventoryMovementInput,
  DeleteInventoryStockInput,
  FilterOperator,
  InventoryItem,
  InventoryItemWithStock,
  InventoryListQuery,
  InventoryMovement,
  InventoryStock,
  PaginatedResult,
  UpdateInventoryItemInput,
  UpdateInventoryMovementInput,
  UpdateInventoryStockInput,
} from '../types'

const normalizeText = (value: string | null | undefined) => {
  if (typeof value !== 'string') {
    return value ?? null
  }

  const trimmed = value.trim()

  return trimmed.length > 0 ? trimmed : null
}

const sanitizePage = (value: number | undefined, fallback: number) =>
  Number.isFinite(value) && (value ?? 0) > 0 ? Math.floor(value as number) : fallback

type FilterQueryBuilder<Q> = {
  ilike: (column: string, pattern: string) => Q
  gte: (column: string, value: unknown) => Q
  lte: (column: string, value: unknown) => Q
  in: (column: string, value: unknown[]) => Q
  eq: (column: string, value: unknown) => Q
}

const applyFilters = <Q extends FilterQueryBuilder<Q>, T extends string>(
  query: Q,
  filters: Record<string, unknown> | undefined,
  operators: Record<string, FilterOperator> | undefined,
  allowlist: readonly T[],
): Q => {
  if (!filters) {
    return query
  }

  const allowedSet = new Set<string>(allowlist)

  Object.entries(filters).forEach(([field, value]) => {
    if (!allowedSet.has(field) || value === undefined) {
      return
    }

    const operator = operators?.[field] ?? 'eq'

    if (operator === 'ilike' && typeof value === 'string') {
      query = query.ilike(field, `%${value}%`)
      return
    }

    if (operator === 'gte') {
      query = query.gte(field, value)
      return
    }

    if (operator === 'lte') {
      query = query.lte(field, value)
      return
    }

    if (operator === 'in' && Array.isArray(value)) {
      query = query.in(field, value)
      return
    }

    query = query.eq(field, value)
  })

  return query
}

const isAllowedField = <T extends string>(
  value: string | undefined,
  allowlist: readonly T[],
): value is T => !!value && (allowlist as readonly string[]).includes(value)

const toNullableText = (value: unknown): string | null =>
  typeof value === 'string' ? value : null

const toNumberOrZero = (value: unknown): number => {
  const numberValue = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(numberValue) ? numberValue : 0
}

const listWithQuery = async <T extends string, R>(
  tableName: string,
  queryInput: InventoryListQuery,
  allowlist: readonly T[],
  defaultSortBy: T,
): Promise<PaginatedResult<R>> => {
  const pageSize = sanitizePage(queryInput.pageSize, 20)
  const page = sanitizePage(queryInput.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from(tableName).select('*', { count: 'exact' })

  if (typeof queryInput.tenant_id === 'number' && tableName === 'inventory_items') {
    query = query.eq('tenant_id', queryInput.tenant_id)
  }

  query = applyFilters(query, queryInput.filters, queryInput.operators, allowlist)

  const safeSortBy =
    typeof queryInput.sortBy === 'string' && allowlist.includes(queryInput.sortBy as T)
      ? (queryInput.sortBy as T)
      : defaultSortBy

  const ascending = queryInput.sortOrder !== 'desc'

  query = query.order(safeSortBy, { ascending }).range(from, to)

  const { data, error, count } = await query

  if (error) {
    throw error
  }

  return {
    rows: (data as R[] | null) ?? [],
    total: count ?? 0,
    page,
    pageSize,
  }
}

const INVENTORY_ITEM_FILTERABLE_FIELDS = [
  'id',
  'tenant_id',
  'source_type',
  'source_id',
  'name',
  'image_url',
  'cost',
  'manufacturing_date',
  'expire_date',
  'status',
  'created_at',
  'updated_at',
] as const

const INVENTORY_STOCK_FILTERABLE_FIELDS = [
  'id',
  'inventory_item_id',
  'available_quantity',
  'reserved_quantity',
  'damaged_quantity',
  'stolen_quantity',
  'expired_quantity',
  'created_at',
  'updated_at',
] as const

const INVENTORY_MOVEMENT_FILTERABLE_FIELDS = [
  'id',
  'inventory_item_id',
  'type',
  'quantity',
  'previous_quantity',
  'new_quantity',
  'note',
  'created_by',
  'created_at',
] as const

const listInventoryItems = async (
  payload: InventoryListQuery = {},
): Promise<PaginatedResult<InventoryItemWithStock>> => {
  if (typeof payload.tenant_id !== 'number') {
    throw new Error('tenant_id is required to fetch inventory items.')
  }

  const pageSize = sanitizePage(payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const safeSortBy = isAllowedField(payload.sortBy, INVENTORY_ITEM_FILTERABLE_FIELDS)
    ? payload.sortBy
    : 'id'
  const safeSortOrder = payload.sortOrder === 'asc' ? 'asc' : 'desc'

  const { data, error } = await supabase.rpc('list_inventory_items_with_stock', {
    p_tenant_id: payload.tenant_id,
    p_page: page,
    p_page_size: pageSize,
    p_sort_by: safeSortBy,
    p_sort_order: safeSortOrder,
    p_filters: payload.filters ?? {},
  })

  if (error) {
    throw error
  }

  const rows = (data as Array<Record<string, unknown>> | null) ?? []

  const mappedRows: InventoryItemWithStock[] = rows.map((row) => ({
    id: toNumberOrZero(row.id),
    tenant_id: toNumberOrZero(row.tenant_id),
    source_type: row.source_type as InventoryItem['source_type'],
    source_id: row.source_id == null ? null : toNumberOrZero(row.source_id),
    name: toNullableText(row.name) ?? '',
    image_url: toNullableText(row.image_url),
    cost: row.cost == null ? null : toNumberOrZero(row.cost),
    manufacturing_date: toNullableText(row.manufacturing_date),
    expire_date: toNullableText(row.expire_date),
    status: row.status as InventoryItem['status'],
    created_at: toNullableText(row.created_at) ?? '',
    updated_at: toNullableText(row.updated_at) ?? '',
    stock:
      row.stock_id == null
        ? null
        : {
            id: toNumberOrZero(row.stock_id),
            inventory_item_id: toNumberOrZero(row.id),
            available_quantity: toNumberOrZero(row.available_quantity),
            reserved_quantity: toNumberOrZero(row.reserved_quantity),
            damaged_quantity: toNumberOrZero(row.damaged_quantity),
            stolen_quantity: toNumberOrZero(row.stolen_quantity),
            expired_quantity: toNumberOrZero(row.expired_quantity),
            created_at: toNullableText(row.stock_created_at) ?? '',
            updated_at: toNullableText(row.stock_updated_at) ?? '',
          },
    quantities: {
      available: toNumberOrZero(row.available_quantity),
      reserved: toNumberOrZero(row.reserved_quantity),
      damaged: toNumberOrZero(row.damaged_quantity),
      stolen: toNumberOrZero(row.stolen_quantity),
      expired: toNumberOrZero(row.expired_quantity),
    },
  }))

  const firstRow = rows[0]
  const total = firstRow ? Number(firstRow.total_count ?? 0) : 0

  return {
    rows: mappedRows,
    total,
    page,
    pageSize,
  }
}

const getInventoryItemById = async (id: number): Promise<InventoryItem> => {
  const { data, error } = await supabase
    .from('inventory_items')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory item not found.')
  }

  return data as InventoryItem
}

const createInventoryItem = async (payload: CreateInventoryItemInput): Promise<InventoryItem> => {
  const insertData = {
    ...payload,
    name: payload.name.trim(),
    image_url: normalizeText(payload.image_url),
  }

  const { data, error } = await supabase
    .from('inventory_items')
    .insert([insertData])
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory item was not created.')
  }

  return data as InventoryItem
}

const updateInventoryItem = async (payload: UpdateInventoryItemInput): Promise<InventoryItem> => {
  const patch = { ...payload.patch }

  if ('name' in patch && typeof patch.name === 'string') {
    patch.name = patch.name.trim()
  }

  if ('image_url' in patch) {
    patch.image_url = normalizeText(patch.image_url)
  }

  const { data, error } = await supabase
    .from('inventory_items')
    .update(patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory item was not updated.')
  }

  return data as InventoryItem
}

const deleteInventoryItem = async (payload: DeleteInventoryItemInput): Promise<void> => {
  const { error } = await supabase.from('inventory_items').delete().eq('id', payload.id)

  if (error) {
    throw error
  }
}

const listInventoryStocks = async (
  payload: InventoryListQuery = {},
): Promise<PaginatedResult<InventoryStock>> => {
  const pageSize = sanitizePage(payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase
    .from('inventory_stocks')
    .select('*, inventory_items!inner(tenant_id)', { count: 'exact' })

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('inventory_items.tenant_id', payload.tenant_id)
  }

  query = applyFilters(query, payload.filters, payload.operators, INVENTORY_STOCK_FILTERABLE_FIELDS)

  const safeSortBy = isAllowedField(payload.sortBy, INVENTORY_STOCK_FILTERABLE_FIELDS)
    ? payload.sortBy
    : 'id'
  const ascending = payload.sortOrder !== 'desc'

  const { data, error, count } = await query
    .order(safeSortBy, { ascending })
    .range(from, to)

  if (error) {
    throw error
  }

  const rows = ((data as Array<InventoryStock & { inventory_items?: unknown }> | null) ?? []).map(
    (row) => {
      const stock = { ...row }
      delete (stock as { inventory_items?: unknown }).inventory_items
      return stock as InventoryStock
    },
  )

  return {
    rows,
    total: count ?? 0,
    page,
    pageSize,
  }
}

const getInventoryStockById = async (id: number): Promise<InventoryStock> => {
  const { data, error } = await supabase
    .from('inventory_stocks')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory stock not found.')
  }

  return data as InventoryStock
}

const createInventoryStock = async (
  payload: CreateInventoryStockInput,
): Promise<InventoryStock> => {
  const { data, error } = await supabase
    .from('inventory_stocks')
    .insert([payload])
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory stock was not created.')
  }

  return data as InventoryStock
}

const updateInventoryStock = async (
  payload: UpdateInventoryStockInput,
): Promise<InventoryStock> => {
  const { data, error } = await supabase
    .from('inventory_stocks')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory stock was not updated.')
  }

  return data as InventoryStock
}

const deleteInventoryStock = async (payload: DeleteInventoryStockInput): Promise<void> => {
  const { error } = await supabase.from('inventory_stocks').delete().eq('id', payload.id)

  if (error) {
    throw error
  }
}

const listInventoryMovements = async (
  payload: InventoryListQuery = {},
): Promise<PaginatedResult<InventoryMovement>> =>
  listWithQuery<'id' | 'inventory_item_id' | 'type' | 'quantity' | 'previous_quantity' | 'new_quantity' | 'note' | 'created_by' | 'created_at', InventoryMovement>(
    'inventory_movements',
    payload,
    INVENTORY_MOVEMENT_FILTERABLE_FIELDS,
    'id',
  )

const getInventoryMovementById = async (id: number): Promise<InventoryMovement> => {
  const { data, error } = await supabase
    .from('inventory_movements')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory movement not found.')
  }

  return data as InventoryMovement
}

const createInventoryMovement = async (
  payload: CreateInventoryMovementInput,
): Promise<InventoryMovement> => {
  const { data, error } = await supabase
    .from('inventory_movements')
    .insert([{ ...payload, note: normalizeText(payload.note) }])
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory movement was not created.')
  }

  return data as InventoryMovement
}

const updateInventoryMovement = async (
  payload: UpdateInventoryMovementInput,
): Promise<InventoryMovement> => {
  const patch = { ...payload.patch }

  if ('note' in patch) {
    patch.note = normalizeText(patch.note)
  }

  const { data, error } = await supabase
    .from('inventory_movements')
    .update(patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Inventory movement was not updated.')
  }

  return data as InventoryMovement
}

const deleteInventoryMovement = async (payload: DeleteInventoryMovementInput): Promise<void> => {
  const { error } = await supabase.from('inventory_movements').delete().eq('id', payload.id)

  if (error) {
    throw error
  }
}

export const inventoryRepository = {
  listInventoryItems,
  getInventoryItemById,
  createInventoryItem,
  updateInventoryItem,
  deleteInventoryItem,
  listInventoryStocks,
  getInventoryStockById,
  createInventoryStock,
  updateInventoryStock,
  deleteInventoryStock,
  listInventoryMovements,
  getInventoryMovementById,
  createInventoryMovement,
  updateInventoryMovement,
  deleteInventoryMovement,
}
