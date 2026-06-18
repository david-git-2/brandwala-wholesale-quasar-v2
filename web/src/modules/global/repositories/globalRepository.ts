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
  GlobalShipmentAccountingRow,
  GlobalShipmentInvestmentRow,
  GlobalStockListPage,
  GlobalStockListQuery,
  GlobalStockRow,
  InvoiceChargeLineRow,
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
      'id, tenant_id, parent_tenant_id, invoice_no, invoice_type, payment_status, invoice_date, total_amount, due_amount, paid_amount, billing_profile_id, recipient_name, billing_profiles(name)',
    )
    .eq('parent_tenant_id', parentTenantId)
    .order('id', { ascending: false })
    .limit(200)

  if (error) throw error

  return ((data as Array<GlobalInvoiceRow & { billing_profiles?: { name: string } | null }> | null) ?? []).map(
    (row) => ({
      ...row,
      billing_profile_name: row.billing_profiles?.name ?? null,
    }),
  )
}

const createGlobalInvoice = async (
  payload: CreateGlobalInvoiceInput,
): Promise<GlobalInvoiceCreated> => {
  const { data, error } = await supabase.rpc('create_global_invoice', {
    p_tenant_id: payload.tenant_id,
    p_invoice_no: payload.invoice_no.trim(),
    p_billing_profile_id: payload.billing_profile_id,
    p_invoice_type: payload.invoice_type ?? 'wholesale',
    p_recipient_name: payload.recipient_name ?? null,
    p_recipient_phone: payload.recipient_phone ?? null,
    p_recipient_address: payload.recipient_address ?? null,
    p_recipient_party_id: payload.recipient_party_id ?? null,
    p_middle_man_payout_amount: payload.middle_man_payout_amount ?? null,
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
  return_charge_amount?: number
}) => {
  const { data, error } = await supabase.rpc('add_global_return_item', {
    p_invoice_id: payload.invoice_id,
    p_invoice_item_id: payload.invoice_item_id,
    p_quantity: payload.quantity,
    p_return_charge_amount: payload.return_charge_amount ?? 0,
    p_note: null,
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

export const globalRepository = {
  listGlobalStockPage,
  deleteGlobalStock,
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
  listGlobalInvoiceAccounting,
  getParentCashCirculation,
  listGlobalShipmentInvestments,
}
