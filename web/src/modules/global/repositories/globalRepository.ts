import { supabase } from 'src/boot/supabase'

import type {
  GlobalStockListPage,
  GlobalStockListQuery,
  StockNetworkPage,
  StockNetworkQuery,
  AllocationReconciliationRow,
  ChildStockAllocationRow,
} from '../types'
import { mapStockNetworkToGlobalStockRow } from '../utils/mapStockNetworkRow'

const sanitizePage = (value: number | undefined, fallback: number) => {
  const parsed = typeof value === 'number' ? value : fallback
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback
}

const searchStockNetwork = async (payload: StockNetworkQuery): Promise<StockNetworkPage> => {
  const pageSize = sanitizePage(payload.page_size, 20)
  const page = sanitizePage(payload.page, 1)
  const offset = (page - 1) * pageSize
  const search = payload.search?.trim() || null
  const mode = payload.mode ?? 'search'

  const [listResult, countResult] = await Promise.all([
    supabase.rpc('search_stock_network', {
      p_context_tenant_id: payload.context_tenant_id,
      p_mode: mode,
      p_search: search,
      p_search_field: payload.search_field ?? null,
      p_product_id: payload.product_id ?? null,
      p_status: payload.status ?? 'excellent',
      p_shipment_id: payload.shipment_id ?? null,
      p_exclude_zero_qty: payload.exclude_zero_qty ?? true,
      p_limit: pageSize,
      p_offset: offset,
    }),
    supabase.rpc('count_search_stock_network', {
      p_context_tenant_id: payload.context_tenant_id,
      p_mode: mode,
      p_search: search,
      p_search_field: payload.search_field ?? null,
      p_product_id: payload.product_id ?? null,
      p_status: payload.status ?? 'excellent',
      p_shipment_id: payload.shipment_id ?? null,
      p_exclude_zero_qty: payload.exclude_zero_qty ?? true,
    }),
  ])

  if (listResult.error) throw listResult.error
  if (countResult.error) throw countResult.error

  const total = Number(countResult.data ?? 0)
  const rows = (listResult.data as StockNetworkPage['data'] | null) ?? []

  return {
    data: rows,
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const listGlobalStockPage = async (
  payload: GlobalStockListQuery,
): Promise<GlobalStockListPage> => {
  const networkQuery: StockNetworkQuery = {
    context_tenant_id: payload.tenant_id,
    mode: 'page',
    search: payload.search ?? null,
    exclude_zero_qty: payload.exclude_zero_qty ?? true,
  }
  if (payload.search_field) networkQuery.search_field = payload.search_field
  if (payload.shipment_id != null) networkQuery.shipment_id = payload.shipment_id
  if (payload.page) networkQuery.page = payload.page
  if (payload.page_size) networkQuery.page_size = payload.page_size

  const result = await searchStockNetwork(networkQuery)

  return {
    data: result.data.map(mapStockNetworkToGlobalStockRow),
    meta: result.meta,
  }
}

const deleteGlobalStock = async (id: number): Promise<void> => {
  const { error } = await supabase.from('global_stocks').delete().eq('id', id)
  if (error) throw error
}

const listChildStockAllocations = async (
  parentTenantId: number,
  status: StockNetworkQuery['status'] = 'excellent',
): Promise<ChildStockAllocationRow[]> => {
  const { data, error } = await supabase
    .from('child_tenant_stock_allocations')
    .select('id, parent_tenant_id, child_tenant_id, stock_id, status, quantity, is_display_only, created_at, updated_at')
    .eq('parent_tenant_id', parentTenantId)
    .eq('status', status ?? 'excellent')

  if (error) throw error
  return (data) ?? []
}

const getAllocationReconciliation = async (
  stockId: number,
  status: StockNetworkQuery['status'] = 'excellent',
): Promise<AllocationReconciliationRow> => {
  const { data, error } = await supabase.rpc('get_allocation_reconciliation', {
    p_stock_id: stockId,
    p_status: status ?? 'excellent',
  })

  if (error) throw error
  const rows = (data as AllocationReconciliationRow[] | null) ?? []
  if (!rows.length) {
    return {
      stock_id: stockId,
      status: status ?? 'excellent',
      global_qty: 0,
      allocated_qty: 0,
      unallocated_qty: 0,
      is_reconciled: true,
    }
  }
  return rows[0]!
}

const upsertChildStockAllocation = async (payload: {
  parent_tenant_id: number
  child_tenant_id: number
  stock_id: number
  quantity: number
  status?: StockNetworkQuery['status']
  is_display_only?: boolean
}): Promise<ChildStockAllocationRow> => {
  const { data, error } = await supabase.rpc('upsert_child_stock_allocation', {
    p_parent_tenant_id: payload.parent_tenant_id,
    p_child_tenant_id: payload.child_tenant_id,
    p_stock_id: payload.stock_id,
    p_quantity: payload.quantity,
    p_status: payload.status ?? 'excellent',
    p_is_display_only: payload.is_display_only ?? true,
  })

  if (error) throw error
  return data as ChildStockAllocationRow
}

export const globalRepository = {
  searchStockNetwork,
  listGlobalStockPage,
  deleteGlobalStock,
  getAllocationReconciliation,
  listChildStockAllocations,
  upsertChildStockAllocation,
}
