import { supabase } from 'src/boot/supabase'
import type {
  CreateInvoiceItemInput,
  CreateInvoiceInput,
  DeleteInvoiceItemInput,
  DeleteInvoiceInput,
  FilterOperator,
  Invoice,
  InvoiceItem,
  InvoiceListPage,
  InvoiceListQuery,
  UpdateInvoiceItemInput,
  UpdateInvoiceInput,
} from '../types/index'

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

const INVOICE_FIELDS = [
  'id',
  'tenant_id',
  'billing_profile_id',
  'customer_group_id',
  'invoice_no',
  'source_type',
  'source_id',
  'payment_status',
  'status',
  'invoice_date',
  'due_date',
  'subtotal_amount',
  'discount_amount',
  'total_amount',
  'paid_amount',
  'note',
  'created_by',
  'created_at',
  'updated_at',
] as const
const INVOICE_FIELDS_ALLOWLIST: readonly string[] = INVOICE_FIELDS
const INVOICE_ITEM_FIELDS = [
  'id',
  'tenant_id',
  'invoice_id',
  'shipment_id',
  'source_item_type',
  'source_item_id',
  'inventory_item_id',
  'product_id',
  'name_snapshot',
  'barcode_snapshot',
  'product_code_snapshot',
  'quantity',
  'cost_amount',
  'sell_price_amount',
  'line_discount_amount',
  'line_tax_amount',
  'line_total_amount',
  'created_at',
  'updated_at',
] as const

const listInvoices = async (payload: InvoiceListQuery = {}): Promise<InvoiceListPage<Invoice>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('invoices').select('*', { count: 'exact' })

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }

  query = applyFilters(query, payload.filters, payload.operators, INVOICE_FIELDS)

  const sortBy =
    typeof payload.sortBy === 'string' && INVOICE_FIELDS_ALLOWLIST.includes(payload.sortBy)
      ? payload.sortBy
      : 'created_at'

  query = query.order(sortBy, { ascending: payload.sortOrder === 'asc' }).range(from, to)

  const { data, error, count } = await query
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as Invoice[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createInvoice = async (payload: CreateInvoiceInput) => {
  const { data, error } = await supabase.from('invoices').insert([payload]).select('*').single()
  if (error) throw error
  return data as Invoice
}

const updateInvoice = async (payload: UpdateInvoiceInput) => {
  const { data, error } = await supabase
    .from('invoices')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()
  if (error) throw error
  return data as Invoice
}

const deleteInvoice = async (payload: DeleteInvoiceInput) => {
  const { error } = await supabase.from('invoices').delete().eq('id', payload.id)
  if (error) throw error
}

const createInvoiceItem = async (payload: CreateInvoiceItemInput) => {
  const { data, error } = await supabase.from('invoice_items').insert([payload]).select('*').single()
  if (error) throw error
  return data as InvoiceItem
}

const updateInvoiceItem = async (payload: UpdateInvoiceItemInput) => {
  const { data, error } = await supabase
    .from('invoice_items')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()
  if (error) throw error
  return data as InvoiceItem
}

const deleteInvoiceItem = async (payload: DeleteInvoiceItemInput) => {
  const { error } = await supabase.from('invoice_items').delete().eq('id', payload.id)
  if (error) throw error
}

const listInvoiceItems = async (payload: InvoiceListQuery = {}): Promise<InvoiceListPage<InvoiceItem>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 50)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('invoice_items').select('*', { count: 'exact' })
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }
  query = applyFilters(query, payload.filters, payload.operators, INVOICE_ITEM_FIELDS)

  const sortBy =
    typeof payload.sortBy === 'string' && INVOICE_ITEM_FIELDS.includes(payload.sortBy as never)
      ? payload.sortBy
      : 'created_at'

  query = query.order(sortBy, { ascending: payload.sortOrder === 'asc' }).range(from, to)
  const { data, error, count } = await query
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as InvoiceItem[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

export const invoiceRepository = {
  listInvoices,
  listInvoiceItems,
  createInvoice,
  updateInvoice,
  deleteInvoice,
  createInvoiceItem,
  updateInvoiceItem,
  deleteInvoiceItem,
}
