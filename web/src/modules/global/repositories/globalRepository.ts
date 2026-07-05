import { supabase } from 'src/boot/supabase'

import type {
  BusinessPartyRow,
  CreateGlobalInvoiceInput,
  GlobalInvoiceAccountingRow,
  GlobalInvoiceCreated,
  GlobalInvoiceDetail,
  GlobalInvoiceItemRow,
  GlobalInvoiceRow,
  GlobalLedgerRow,
  GlobalShipmentLedgerEntry,
  GlobalShipmentAccountingRow,
  GlobalShipmentInvestmentRow,
  GlobalStockListPage,
  GlobalStockListQuery,
  InvoiceChargeLineRow,
  ParentCashCirculation,
  StockNetworkPage,
  StockNetworkQuery,
  StockNetworkRow,
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
  const rows = (listResult.data as StockNetworkRow[] | null) ?? []

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

const listGlobalInvoices = async (parentTenantId: number): Promise<GlobalInvoiceRow[]> => {
  const { data, error } = await supabase
    .from('global_invoices')
    .select(
      'id, tenant_id, parent_tenant_id, invoice_no, invoice_type, invoice_status, payment_status, invoice_date, total_amount, due_amount, paid_amount, billing_profile_id, recipient_name, billing_profiles(name)',
    )
    .eq('parent_tenant_id', parentTenantId)
    .order('id', { ascending: false })
    .limit(200)

  if (error) throw error

  type GlobalInvoiceListRow = GlobalInvoiceRow & {
    billing_profiles?: { name: string } | { name: string }[] | null
  }

  return ((data as GlobalInvoiceListRow[] | null) ?? []).map((row) => {
    const billingProfile = Array.isArray(row.billing_profiles)
      ? row.billing_profiles[0] ?? null
      : row.billing_profiles ?? null

    return {
      ...row,
      billing_profile_name: billingProfile?.name ?? null,
    }
  })
}

const createGlobalInvoice = async (
  payload: CreateGlobalInvoiceInput,
): Promise<GlobalInvoiceCreated> => {
  const { data, error } = await supabase.rpc('create_global_invoice', {
    p_tenant_id: payload.tenant_id,
    p_invoice_no: payload.invoice_no.trim(),
    p_billing_profile_id: payload.billing_profile_id ?? null,
    p_recipient_profile_id: payload.recipient_profile_id ?? null,
    p_invoice_type: payload.invoice_type ?? 'wholesale',
    p_recipient_name: payload.recipient_name ?? null,
    p_recipient_phone: payload.recipient_phone ?? null,
    p_recipient_address: payload.recipient_address ?? null,
    p_retail_billing_mode: payload.retail_billing_mode ?? null,
    p_due_date: payload.due_date ?? null,
    p_note: payload.note?.trim() || null,
  })


  if (error) throw error
  if (!data) throw new Error('Global invoice was not created.')

  return data as GlobalInvoiceCreated
}

const getGlobalInvoiceById = async (invoiceId: number): Promise<GlobalInvoiceDetail> => {
  const { data, error } = await supabase
    .from('global_invoices')
    .select('*, billing_profiles(id, name, email, phone, address, color)')
    .eq('id', invoiceId)
    .single()

  if (error) throw error
  return data as GlobalInvoiceDetail
}

const listGlobalInvoiceItems = async (invoiceId: number): Promise<GlobalInvoiceItemRow[]> => {
  const { data, error } = await supabase
    .from('global_invoice_items')
    .select(
      'id, invoice_id, global_stock_id, name_snapshot, quantity, cost_amount, sell_price_amount, recipient_price_amount, line_face_total_amount, line_discount_amount, line_total_amount',
    )
    .eq('invoice_id', invoiceId)
    .order('id', { ascending: true })

  if (error) throw error
  return (data as GlobalInvoiceItemRow[] | null) ?? []
}

const listInvoiceChargeLines = async (invoiceId: number): Promise<InvoiceChargeLineRow[]> => {
  const { data, error } = await supabase
    .from('invoice_charge_lines')
    .select('id, invoice_id, charge_type, amount, note')
    .eq('invoice_id', invoiceId)

  if (error) throw error
  return (data as InvoiceChargeLineRow[] | null) ?? []
}

const upsertInvoiceChargeLine = async (
  invoiceId: number,
  chargeType: string,
  amount: number,
  note?: string | null,
): Promise<InvoiceChargeLineRow> => {
  const { data, error } = await supabase.rpc('upsert_invoice_charge_line', {
    p_invoice_id: invoiceId,
    p_charge_type: chargeType,
    p_amount: amount,
    p_note: note ?? null,
  })

  if (error) throw error
  return data as InvoiceChargeLineRow
}

const addGlobalInvoiceItem = async (payload: {
  invoice_id: number
  global_stock_id: number
  quantity: number
  sell_price_amount: number
  line_discount_amount?: number
  recipient_price_amount?: number
}): Promise<GlobalInvoiceItemRow> => {
  const { data, error } = await supabase.rpc('add_global_invoice_item', {
    p_invoice_id: payload.invoice_id,
    p_global_stock_id: payload.global_stock_id,
    p_quantity: payload.quantity,
    p_sell_price_amount: payload.sell_price_amount,
    p_line_discount_amount: payload.line_discount_amount ?? 0,
    p_recipient_price_amount: payload.recipient_price_amount ?? null,
  })

  if (error) throw error
  return data as GlobalInvoiceItemRow
}

const recordBillingProfilePayment = async (payload: {
  tenant_id: number
  billing_profile_id: number
  amount: number
  allocations: Array<{ global_invoice_id: number; amount: number }>
}) => {
  const { data, error } = await supabase.rpc('create_billing_profile_payment_with_allocations', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_amount: payload.amount,
    p_payment_date: new Date().toISOString().slice(0, 10),
    p_method: 'cash',
    p_reference: null,
    p_note: null,
    p_allocations: payload.allocations.map((a) => ({
      global_invoice_id: a.global_invoice_id,
      amount: a.amount,
    })),
  })
  if (error) throw error
  return data
}

const recordRecipientInvoiceCollection = async (globalInvoiceId: number, amount: number) => {
  const { data, error } = await supabase.rpc('record_recipient_invoice_collection', {
    p_global_invoice_id: globalInvoiceId,
    p_amount: amount,
    p_note: null,
  })
  if (error) throw error
  return data
}

const createMiddleManPayout = async (payload: {
  tenant_id: number
  billing_profile_id: number
  global_invoice_id: number
  amount: number
}) => {
  const { data, error } = await supabase.rpc('create_middle_man_payout', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_global_invoice_id: payload.global_invoice_id,
    p_amount: payload.amount,
    p_note: null,
  })
  if (error) throw error
  return data
}

const addGlobalReturnItem = async (payload: {
  invoice_id: number
  invoice_item_id: number
  quantity: number
  return_face_amount: number
  return_accounting_amount: number
  return_charge_amount?: number
  note?: string | null
}) => {
  const { data, error } = await supabase.rpc('add_global_return_item', {
    p_invoice_id: payload.invoice_id,
    p_invoice_item_id: payload.invoice_item_id,
    p_quantity: payload.quantity,
    p_return_face_amount: payload.return_face_amount,
    p_return_accounting_amount: payload.return_accounting_amount,
    p_return_charge_amount: payload.return_charge_amount ?? 0,
    p_note: payload.note ?? null,
  })
  if (error) throw error
  return data
}

const listBusinessParties = async (
  parentTenantId: number,
  tenantId?: number | null,
): Promise<BusinessPartyRow[]> => {
  let query = supabase
    .from('business_parties')
    .select('id, tenant_id, parent_tenant_id, name, party_type, phone, email, address, is_active')
    .eq('parent_tenant_id', parentTenantId)
    .eq('is_active', true)
    .order('name', { ascending: true })

  if (typeof tenantId === 'number') {
    query = query.eq('tenant_id', tenantId)
  }

  const { data, error } = await query
  if (error) throw error
  return (data as BusinessPartyRow[] | null) ?? []
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

const listGlobalLedgerByShipment = async (
  parentTenantId: number,
  shipmentId: number,
  limit = 500,
): Promise<GlobalShipmentLedgerEntry[]> => {
  const { data, error } = await supabase.rpc('list_global_accounting_ledger_by_shipment', {
    p_parent_tenant_id: parentTenantId,
    p_shipment_id: shipmentId,
    p_limit: limit,
    p_offset: 0,
  })

  if (error) throw error
  return (data as GlobalShipmentLedgerEntry[] | null) ?? []
}

const refreshGlobalShipmentAccounting = async (
  parentTenantId: number,
  shipmentId: number,
): Promise<GlobalShipmentAccountingRow> => {
  const { data, error } = await supabase.rpc('refresh_global_shipment_accounting', {
    p_parent_tenant_id: parentTenantId,
    p_shipment_id: shipmentId,
  })

  if (error) throw error
  if (!data) throw new Error('Failed to refresh shipment accounting.')
  return data as GlobalShipmentAccountingRow
}

const getGlobalInvoicesPaidAmounts = async (
  invoiceIds: number[],
): Promise<Record<string, number>> => {
  if (!invoiceIds.length) return {}

  const { data, error } = await supabase
    .from('global_invoices')
    .select('id, paid_amount')
    .in('id', invoiceIds)

  if (error) throw error

  const paidAmounts: Record<string, number> = {}
  for (const invoice of data ?? []) {
    paidAmounts[`normal_${invoice.id}`] = Number(invoice.paid_amount ?? 0)
  }
  return paidAmounts
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
  return (data as ChildStockAllocationRow[] | null) ?? []
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

const removeGlobalInvoiceItem = async (invoiceItemId: number): Promise<void> => {
  const { error } = await supabase.rpc('remove_global_invoice_item', {
    p_invoice_item_id: invoiceItemId,
  })
  if (error) throw error
}

const updateGlobalInvoiceHeader = async (payload: {
  id: number
  discount_amount?: number | null
  shipping_charge?: number | null
  cod_charge?: number | null
  wrapping_charge?: number | null
  print_charge?: number | null
  recipient_name?: string | null
  recipient_phone?: string | null
  recipient_address?: string | null
  note?: string | null
}): Promise<void> => {
  const { error } = await supabase.rpc('update_global_invoice_header', {
    p_invoice_id: payload.id,
    p_discount_amount: payload.discount_amount,
    p_shipping_charge: payload.shipping_charge,
    p_cod_charge: payload.cod_charge,
    p_wrapping_charge: payload.wrapping_charge,
    p_print_charge: payload.print_charge,
    p_recipient_name: payload.recipient_name,
    p_recipient_phone: payload.recipient_phone,
    p_recipient_address: payload.recipient_address,
    p_note: payload.note,
  })
  if (error) throw error
}

const postGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('post_global_invoice', {
    p_invoice_id: invoiceId,
  })
  if (error) throw error
}

const voidGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('void_global_invoice', {
    p_invoice_id: invoiceId,
  })
  if (error) throw error
}

const deleteGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.from('global_invoices').delete().eq('id', invoiceId)
  if (error) throw error
}

export const globalRepository = {
  searchStockNetwork,
  listGlobalStockPage,
  deleteGlobalStock,
  getAllocationReconciliation,
  listChildStockAllocations,
  upsertChildStockAllocation,
  listGlobalInvoices,
  createGlobalInvoice,
  getGlobalInvoiceById,
  listGlobalInvoiceItems,
  listInvoiceChargeLines,
  upsertInvoiceChargeLine,
  addGlobalInvoiceItem,
  recordBillingProfilePayment,
  recordRecipientInvoiceCollection,
  createMiddleManPayout,
  addGlobalReturnItem,
  listBusinessParties,
  listGlobalLedger,
  listGlobalShipmentAccounting,
  getGlobalShipmentAccounting,
  listGlobalLedgerByShipment,
  refreshGlobalShipmentAccounting,
  getGlobalInvoicesPaidAmounts,
  listGlobalInvoiceAccounting,
  getParentCashCirculation,
  listGlobalShipmentInvestments,
  removeGlobalInvoiceItem,
  updateGlobalInvoiceHeader,
  postGlobalInvoice,
  voidGlobalInvoice,
  deleteGlobalInvoice,
}
