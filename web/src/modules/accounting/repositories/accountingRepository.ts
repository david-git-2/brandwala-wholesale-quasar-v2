import { supabase } from 'src/boot/supabase'
import type {
  AccountingListPage,
  AccountingListQuery,
  CreateInventoryAccountingEntryInput,
  CreateInvoiceAccountingPaymentInput,
  DeleteInventoryAccountingEntryInput,
  DeleteInvoiceAccountingPaymentInput,
  FilterOperator,
  InventoryAccountingEntry,
  InvoiceAccountingPayment,
  UpdateInventoryAccountingEntryInput,
  UpdateInvoiceAccountingPaymentInput,
} from '../types'

const sanitizePage = (value: number | undefined, fallback: number) =>
  Number.isFinite(value) && (value ?? 0) > 0 ? Math.floor(value as number) : fallback

const applyFilters = <
  Q extends {
    eq: (c: string, v: unknown) => Q
    ilike: (c: string, v: string) => Q
    gte: (c: string, v: unknown) => Q
    lte: (c: string, v: unknown) => Q
    in: (c: string, v: unknown[]) => Q
  },
>(
  query: Q,
  filters: Record<string, unknown> | undefined,
  operators: Record<string, FilterOperator> | undefined,
  allowlist: readonly string[],
): Q => {
  if (!filters) return query
  const allowed = new Set(allowlist)
  Object.entries(filters).forEach(([field, value]) => {
    if (!allowed.has(field) || value === undefined) return
    const op = operators?.[field] ?? 'eq'
    if (op === 'ilike' && typeof value === 'string') query = query.ilike(field, `%${value}%`)
    else if (op === 'gte') query = query.gte(field, value)
    else if (op === 'lte') query = query.lte(field, value)
    else if (op === 'in' && Array.isArray(value)) query = query.in(field, value)
    else query = query.eq(field, value)
  })
  return query
}

const INVENTORY_ACCOUNTING_ENTRY_FIELDS = [
  'id',
  'tenant_id',
  'invoice_id',
  'invoice_item_id',
  'inventory_item_id',
  'shipment_id',
  'shipment_item_id',
  'product_id',
  'quantity',
  'cost_amount',
  'sell_price_amount',
  'total_cost_amount',
  'total_sell_amount',
  'gross_profit_amount',
  'status',
  'entry_date',
  'note',
  'created_by',
  'created_at',
  'updated_at',
] as const

const INVOICE_ACCOUNTING_PAYMENT_FIELDS = [
  'id',
  'tenant_id',
  'inventory_accounting_entry_id',
  'amount',
  'payment_date',
  'payment_method',
  'reference_no',
  'note',
  'created_by',
  'created_at',
  'updated_at',
] as const

const listInventoryAccountingEntries = async (
  payload: AccountingListQuery = {},
): Promise<AccountingListPage<InventoryAccountingEntry>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('inventory_accounting_entries').select('*', { count: 'exact' })
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }

  query = applyFilters(query, payload.filters, payload.operators, INVENTORY_ACCOUNTING_ENTRY_FIELDS)
  const sortBy =
    typeof payload.sortBy === 'string' &&
    INVENTORY_ACCOUNTING_ENTRY_FIELDS.includes(payload.sortBy as never)
      ? payload.sortBy
      : 'id'

  const { data, error, count } = await query
    .order(sortBy, { ascending: payload.sortOrder === 'asc' })
    .range(from, to)
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as InventoryAccountingEntry[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createInventoryAccountingEntry = async (payload: CreateInventoryAccountingEntryInput) => {
  const { data, error } = await supabase
    .from('inventory_accounting_entries')
    .insert([payload])
    .select('*')
    .single()
  if (error) throw error
  return data as InventoryAccountingEntry
}

const updateInventoryAccountingEntry = async (payload: UpdateInventoryAccountingEntryInput) => {
  const { data, error } = await supabase
    .from('inventory_accounting_entries')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()
  if (error) throw error
  return data as InventoryAccountingEntry
}

const deleteInventoryAccountingEntry = async (payload: DeleteInventoryAccountingEntryInput) => {
  const { error } = await supabase
    .from('inventory_accounting_entries')
    .delete()
    .eq('id', payload.id)
  if (error) throw error
}

const listInvoiceAccountingPayments = async (
  payload: AccountingListQuery = {},
): Promise<AccountingListPage<InvoiceAccountingPayment>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('invoice_accounting_payments').select('*', { count: 'exact' })
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }

  query = applyFilters(query, payload.filters, payload.operators, INVOICE_ACCOUNTING_PAYMENT_FIELDS)
  const sortBy =
    typeof payload.sortBy === 'string' && INVOICE_ACCOUNTING_PAYMENT_FIELDS.includes(payload.sortBy as never)
      ? payload.sortBy
      : 'id'

  const { data, error, count } = await query
    .order(sortBy, { ascending: payload.sortOrder === 'asc' })
    .range(from, to)
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as InvoiceAccountingPayment[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createInvoiceAccountingPayment = async (payload: CreateInvoiceAccountingPaymentInput) => {
  const { data, error } = await supabase
    .from('invoice_accounting_payments')
    .insert([payload])
    .select('*')
    .single()
  if (error) throw error
  return data as InvoiceAccountingPayment
}

const updateInvoiceAccountingPayment = async (payload: UpdateInvoiceAccountingPaymentInput) => {
  const { data, error } = await supabase
    .from('invoice_accounting_payments')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()
  if (error) throw error
  return data as InvoiceAccountingPayment
}

const deleteInvoiceAccountingPayment = async (payload: DeleteInvoiceAccountingPaymentInput) => {
  const { error } = await supabase
    .from('invoice_accounting_payments')
    .delete()
    .eq('id', payload.id)
  if (error) throw error
}

export const accountingRepository = {
  listInventoryAccountingEntries,
  createInventoryAccountingEntry,
  updateInventoryAccountingEntry,
  deleteInventoryAccountingEntry,
  listInvoiceAccountingPayments,
  createInvoiceAccountingPayment,
  updateInvoiceAccountingPayment,
  deleteInvoiceAccountingPayment,
}
