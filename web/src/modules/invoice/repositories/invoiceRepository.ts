import { supabase } from 'src/boot/supabase'
import type {
  CreateInvoiceAccountingPaymentInput,
  CreateInvoiceInput,
  CreateInvoiceItemInput,
  CreateInventoryAccountingEntryInput,
  DeleteInvoiceAccountingPaymentInput,
  DeleteInvoiceInput,
  DeleteInvoiceItemInput,
  DeleteInventoryAccountingEntryInput,
  FilterOperator,
  Invoice,
  InvoiceAccountingPayment,
  InvoiceItem,
  InvoiceListPage,
  InvoiceListQuery,
  InventoryAccountingEntry,
  UpdateInvoiceAccountingPaymentInput,
  UpdateInvoiceInput,
  UpdateInvoiceItemInput,
  UpdateInventoryAccountingEntryInput,
} from '../types'

const sanitizePage = (value: number | undefined, fallback: number) =>
  Number.isFinite(value) && (value ?? 0) > 0 ? Math.floor(value as number) : fallback

const applyFilters = <Q extends { eq: (c: string, v: unknown) => Q; ilike: (c: string, v: string) => Q; gte: (c: string, v: unknown) => Q; lte: (c: string, v: unknown) => Q; in: (c: string, v: unknown[]) => Q }>(
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

const listWithQuery = async <T>(table: string, payload: InvoiceListQuery, allow: readonly string[], sortDefault: string): Promise<InvoiceListPage<T>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from(table).select('*', { count: 'exact' })
  if (typeof payload.tenant_id === 'number') query = query.eq('tenant_id', payload.tenant_id)
  query = applyFilters(query, payload.filters, payload.operators, allow)

  const sortBy = typeof payload.sortBy === 'string' && allow.includes(payload.sortBy) ? payload.sortBy : sortDefault
  query = query.order(sortBy, { ascending: payload.sortOrder === 'asc' }).range(from, to)

  const { data, error, count } = await query
  if (error) throw error

  const total = count ?? 0
  return { data: (data as T[] | null) ?? [], meta: { total, page, page_size: pageSize, total_pages: Math.max(1, Math.ceil(total / pageSize)) } }
}

const invoiceFields = ['id','tenant_id','invoice_no','source_type','source_id','payment_status','invoice_date','due_date','subtotal_amount','discount_amount','total_amount','paid_amount','note','created_by','created_at','updated_at'] as const
const invoiceItemFields = ['id','tenant_id','invoice_id','source_item_type','source_item_id','inventory_item_id','product_id','name_snapshot','barcode_snapshot','product_code_snapshot','quantity','cost_amount','sell_price_amount','line_discount_amount','line_tax_amount','line_total_amount','created_at','updated_at'] as const
const accountingFields = ['id','tenant_id','invoice_id','invoice_item_id','inventory_item_id','product_id','quantity','cost_amount','sell_price_amount','total_cost_amount','total_sell_amount','gross_profit_amount','status','entry_date','note','created_by','created_at','updated_at'] as const
const paymentFields = ['id','tenant_id','inventory_accounting_entry_id','amount','payment_date','payment_method','reference_no','note','created_by','created_at','updated_at'] as const

export const invoiceRepository = {
  listInvoices: (payload: InvoiceListQuery = {}) => listWithQuery<Invoice>('invoices', payload, invoiceFields, 'created_at'),
  async createInvoice(payload: CreateInvoiceInput) { const { data, error } = await supabase.from('invoices').insert([payload]).select('*').single(); if (error) throw error; return data as Invoice },
  async updateInvoice(payload: UpdateInvoiceInput) { const { data, error } = await supabase.from('invoices').update(payload.patch).eq('id', payload.id).select('*').single(); if (error) throw error; return data as Invoice },
  async deleteInvoice(payload: DeleteInvoiceInput) { const { error } = await supabase.from('invoices').delete().eq('id', payload.id); if (error) throw error },

  listInvoiceItems: (payload: InvoiceListQuery = {}) => listWithQuery<InvoiceItem>('invoice_items', payload, invoiceItemFields, 'id'),
  async createInvoiceItem(payload: CreateInvoiceItemInput) { const { data, error } = await supabase.from('invoice_items').insert([payload]).select('*').single(); if (error) throw error; return data as InvoiceItem },
  async updateInvoiceItem(payload: UpdateInvoiceItemInput) { const { data, error } = await supabase.from('invoice_items').update(payload.patch).eq('id', payload.id).select('*').single(); if (error) throw error; return data as InvoiceItem },
  async deleteInvoiceItem(payload: DeleteInvoiceItemInput) { const { error } = await supabase.from('invoice_items').delete().eq('id', payload.id); if (error) throw error },

  listInventoryAccountingEntries: (payload: InvoiceListQuery = {}) => listWithQuery<InventoryAccountingEntry>('inventory_accounting_entries', payload, accountingFields, 'id'),
  async createInventoryAccountingEntry(payload: CreateInventoryAccountingEntryInput) { const { data, error } = await supabase.from('inventory_accounting_entries').insert([payload]).select('*').single(); if (error) throw error; return data as InventoryAccountingEntry },
  async updateInventoryAccountingEntry(payload: UpdateInventoryAccountingEntryInput) { const { data, error } = await supabase.from('inventory_accounting_entries').update(payload.patch).eq('id', payload.id).select('*').single(); if (error) throw error; return data as InventoryAccountingEntry },
  async deleteInventoryAccountingEntry(payload: DeleteInventoryAccountingEntryInput) { const { error } = await supabase.from('inventory_accounting_entries').delete().eq('id', payload.id); if (error) throw error },

  listInvoiceAccountingPayments: (payload: InvoiceListQuery = {}) => listWithQuery<InvoiceAccountingPayment>('invoice_accounting_payments', payload, paymentFields, 'id'),
  async createInvoiceAccountingPayment(payload: CreateInvoiceAccountingPaymentInput) { const { data, error } = await supabase.from('invoice_accounting_payments').insert([payload]).select('*').single(); if (error) throw error; return data as InvoiceAccountingPayment },
  async updateInvoiceAccountingPayment(payload: UpdateInvoiceAccountingPaymentInput) { const { data, error } = await supabase.from('invoice_accounting_payments').update(payload.patch).eq('id', payload.id).select('*').single(); if (error) throw error; return data as InvoiceAccountingPayment },
  async deleteInvoiceAccountingPayment(payload: DeleteInvoiceAccountingPaymentInput) { const { error } = await supabase.from('invoice_accounting_payments').delete().eq('id', payload.id); if (error) throw error },
}
