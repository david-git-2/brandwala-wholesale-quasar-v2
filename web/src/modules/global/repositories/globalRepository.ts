import { supabase } from 'src/boot/supabase'

import type {
  GlobalInvoiceAccountingRow,
  GlobalInvoiceRow,
  GlobalLedgerRow,
  GlobalShipmentAccountingRow,
  GlobalShipmentInvestmentRow,
  GlobalStockListPage,
  GlobalStockListQuery,
  GlobalStockRow,
  ParentCashCirculation,
} from '../types'

const sanitizePage = (value: number | undefined, fallback: number) => {
  const parsed = typeof value === 'number' ? value : fallback
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback
}

const listGlobalStockPage = async (
  payload: GlobalStockListQuery,
): Promise<GlobalStockListPage> => {
  const pageSize = sanitizePage(payload.page_size, 20)
  const page = sanitizePage(payload.page, 1)
  const offset = (page - 1) * pageSize
  const search = payload.search?.trim() || null

  const [listResult, countResult] = await Promise.all([
    supabase.rpc('list_global_stock_for_tenant', {
      p_tenant_id: payload.tenant_id,
      p_search: search,
      p_search_field: payload.search_field ?? null,
      p_shipment_id: payload.shipment_id ?? null,
      p_exclude_zero_qty: payload.exclude_zero_qty ?? true,
      p_limit: pageSize,
      p_offset: offset,
    }),
    supabase.rpc('count_global_stock_for_tenant', {
      p_tenant_id: payload.tenant_id,
      p_search: search,
      p_search_field: payload.search_field ?? null,
      p_shipment_id: payload.shipment_id ?? null,
      p_exclude_zero_qty: payload.exclude_zero_qty ?? true,
    }),
  ])

  if (listResult.error) throw listResult.error
  if (countResult.error) throw countResult.error

  const total = Number(countResult.data ?? 0)
  const rows = (listResult.data as GlobalStockRow[] | null) ?? []

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

const deleteGlobalStock = async (id: number): Promise<void> => {
  const { error } = await supabase.from('global_stocks').delete().eq('id', id)
  if (error) throw error
}

const listGlobalInvoices = async (parentTenantId: number): Promise<GlobalInvoiceRow[]> => {
  const { data, error } = await supabase
    .from('global_invoices')
    .select(
      'id, tenant_id, parent_tenant_id, invoice_no, invoice_type, payment_status, invoice_date, total_amount, due_amount, paid_amount',
    )
    .eq('parent_tenant_id', parentTenantId)
    .order('id', { ascending: false })
    .limit(200)

  if (error) throw error
  return (data as GlobalInvoiceRow[] | null) ?? []
}

const listGlobalLedger = async (
  parentTenantId: number,
  tenantId?: number | null,
): Promise<GlobalLedgerRow[]> => {
  const { data, error } = await supabase.rpc('list_global_accounting_ledger', {
    p_parent_tenant_id: parentTenantId,
    p_tenant_id: tenantId ?? null,
    p_limit: 200,
    p_offset: 0,
  })

  if (error) throw error
  return (data as GlobalLedgerRow[] | null) ?? []
}

const listGlobalShipmentAccounting = async (
  parentTenantId: number,
): Promise<GlobalShipmentAccountingRow[]> => {
  const { data, error } = await supabase
    .from('global_shipment_accounting')
    .select('id, shipment_id, buy_cost_total, sell_total, gross_profit_total, refreshed_at')
    .eq('parent_tenant_id', parentTenantId)
    .order('id', { ascending: false })
    .limit(200)

  if (error) throw error
  return (data as GlobalShipmentAccountingRow[] | null) ?? []
}

const listGlobalInvoiceAccounting = async (
  parentTenantId: number,
): Promise<GlobalInvoiceAccountingRow[]> => {
  const { data, error } = await supabase
    .from('global_invoice_accounting')
    .select(
      'id, global_invoice_id, subtotal_amount, charge_total, total_amount, gross_profit_total, refreshed_at',
    )
    .eq('parent_tenant_id', parentTenantId)
    .order('id', { ascending: false })
    .limit(200)

  if (error) throw error
  return (data as GlobalInvoiceAccountingRow[] | null) ?? []
}

const getParentCashCirculation = async (
  parentTenantId: number,
): Promise<ParentCashCirculation> => {
  const { data, error } = await supabase.rpc('get_parent_cash_circulation', {
    p_parent_tenant_id: parentTenantId,
  })

  if (error) throw error
  return data as ParentCashCirculation
}

const listGlobalShipmentInvestments = async (
  parentTenantId: number,
): Promise<GlobalShipmentInvestmentRow[]> => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .select(
      'id, shipment_id, investor_id, invested_amount, cost_share_pct, allocated_cost, computed_profit, profit_status, status',
    )
    .eq('tenant_id', parentTenantId)
    .order('id', { ascending: false })
    .limit(200)

  if (error) throw error
  return (data as GlobalShipmentInvestmentRow[] | null) ?? []
}

const getGlobalShipmentAccounting = async (
  parentTenantId: number,
  shipmentId: number,
): Promise<GlobalShipmentAccountingRow | null> => {
  const { data, error } = await supabase
    .from('global_shipment_accounting')
    .select('id, shipment_id, buy_cost_total, sell_total, gross_profit_total, refreshed_at')
    .eq('parent_tenant_id', parentTenantId)
    .eq('shipment_id', shipmentId)
    .maybeSingle()

  if (error) throw error
  return (data as GlobalShipmentAccountingRow | null) ?? null
}

export const globalRepository = {
  listGlobalStockPage,
  deleteGlobalStock,
  listGlobalInvoices,
  listGlobalLedger,
  listGlobalShipmentAccounting,
  getGlobalShipmentAccounting,
  listGlobalInvoiceAccounting,
  getParentCashCirculation,
  listGlobalShipmentInvestments,
}
