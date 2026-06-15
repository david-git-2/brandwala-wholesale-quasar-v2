import { supabase } from 'src/boot/supabase'
import type {
  AddPaymentAllocationInput,
  ApplyInvoiceItemReturnInput,
  ApplyInvoiceItemReturnResult,
  CreatePaymentWithAllocationsInput,
  CreateInvoiceItemInput,
  CreateInvoiceInput,
  DeleteInvoiceItemInput,
  DeleteInvoiceInput,
  FilterOperator,
  Invoice,
  InvoiceItem,
  InvoiceListPage,
  InvoiceListQuery,
  Payment,
  PaymentAllocation,
  DeletePaymentInput,
  UpdatePaymentInput,
  UpdateInvoiceItemInput,
  UpdateInvoiceInput,
  UpdatePaymentAllocationAmountInput,
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
  'return_normal_quantity',
  'return_open_box_quantity',
  'return_amount',
  'cost_amount',
  'sell_price_amount',
  'line_discount_amount',
  'line_tax_amount',
  'line_total_amount',
  'created_at',
  'updated_at',
] as const

const PAYMENT_FIELDS = [
  'id',
  'tenant_id',
  'billing_profile_id',
  'amount',
  'payment_date',
  'method',
  'reference',
  'note',
  'created_at',
] as const

const PAYMENT_ALLOCATION_FIELDS = [
  'id',
  'tenant_id',
  'payment_id',
  'invoice_id',
  'amount',
  'created_at',
] as const

const listInvoices = async (payload: InvoiceListQuery = {}): Promise<InvoiceListPage<Invoice>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)

  // Extract search and status if they exist inside filters
  const search = (payload.filters?.search as string) || (payload.filters?.invoice_no as string) || ''
  const status = (payload.filters?.status as string) || ''

  const { data, error } = await supabase.rpc('list_invoices_paginated', {
    p_tenant_id: payload.tenant_id ?? 0,
    p_page: page,
    p_page_size: pageSize,
    p_search: search || null,
    p_status: status || null,
  })

  if (error) throw error

  const result = data as unknown as {
    data: Invoice[]
    meta: {
      total: number
      page: number
      page_size: number
      total_pages: number
    }
  }

  return {
    data: result.data || [],
    meta: {
      total: result.meta?.total || 0,
      page: result.meta?.page || page,
      page_size: result.meta?.page_size || pageSize,
      total_pages: result.meta?.total_pages || 1,
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

const recomputeInvoicePaymentStatus = async (invoiceId: number) => {
  const { error } = await supabase.rpc('recompute_invoice_payment_status', {
    p_invoice_id: invoiceId,
  })
  if (error) throw error
}

const applyInvoiceItemReturn = async (
  payload: ApplyInvoiceItemReturnInput,
): Promise<ApplyInvoiceItemReturnResult> => {
  const { data, error } = await supabase.rpc('apply_invoice_item_return', {
    p_tenant_id: payload.tenant_id,
    p_invoice_item_id: payload.invoice_item_id,
    p_return_normal_quantity: payload.return_normal_quantity,
    p_return_open_box_quantity: payload.return_open_box_quantity,
    p_return_damaged_quantity: payload.return_damaged_quantity,
    p_return_amount: payload.return_amount,
    p_note: payload.note ?? null,
    p_actor: payload.actor ?? null,
    p_return_to_new_batch: payload.return_to_new_batch ?? false,
  })
  if (error) throw error
  if (!data || typeof data !== 'object') {
    throw new Error('Return operation did not return a valid response.')
  }

  const row = data as Record<string, unknown>
  return {
    invoice_id: Number(row.invoice_id ?? 0),
    invoice_item_id: Number(row.invoice_item_id ?? 0),
    return_quantity: Number(row.return_quantity ?? 0),
    return_amount: Number(row.return_amount ?? 0),
  }
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

const listPayments = async (payload: InvoiceListQuery = {}): Promise<InvoiceListPage<Payment>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 50)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('payments').select('*', { count: 'exact' })
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }
  query = applyFilters(query, payload.filters, payload.operators, PAYMENT_FIELDS)

  const sortBy =
    typeof payload.sortBy === 'string' && PAYMENT_FIELDS.includes(payload.sortBy as never)
      ? payload.sortBy
      : 'created_at'

  const { data, error, count } = await query
    .order(sortBy, { ascending: payload.sortOrder === 'asc' })
    .range(from, to)
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as Payment[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const listPaymentAllocations = async (
  payload: InvoiceListQuery = {},
): Promise<InvoiceListPage<PaymentAllocation>> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 200)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('payment_allocations').select('*', { count: 'exact' })
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }
  query = applyFilters(query, payload.filters, payload.operators, PAYMENT_ALLOCATION_FIELDS)

  const sortBy =
    typeof payload.sortBy === 'string' && PAYMENT_ALLOCATION_FIELDS.includes(payload.sortBy as never)
      ? payload.sortBy
      : 'created_at'

  const { data, error, count } = await query
    .order(sortBy, { ascending: payload.sortOrder === 'asc' })
    .range(from, to)
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as PaymentAllocation[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createPaymentWithAllocations = async (
  payload: CreatePaymentWithAllocationsInput,
): Promise<Payment> => {
  const { data, error } = await supabase.rpc('create_billing_profile_payment_with_allocations', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_amount: payload.amount,
    p_payment_date: payload.payment_date,
    p_method: payload.method ?? null,
    p_reference: payload.reference ?? null,
    p_note: payload.note ?? null,
    p_allocations: payload.allocations ?? [],
  })

  if (error) throw error
  if (!data) throw new Error('Payment was not created.')

  return data as Payment
}

const addPaymentAllocation = async (payload: AddPaymentAllocationInput): Promise<PaymentAllocation> => {
  const { data, error } = await supabase.rpc('add_payment_allocation', {
    p_tenant_id: payload.tenant_id,
    p_payment_id: payload.payment_id,
    p_invoice_id: payload.invoice_id,
    p_amount: payload.amount,
  })
  if (error) throw error
  if (!data) throw new Error('Payment allocation was not created.')
  return data as PaymentAllocation
}

const updatePaymentAllocationAmount = async (
  payload: UpdatePaymentAllocationAmountInput,
): Promise<PaymentAllocation> => {
  const { data, error } = await supabase.rpc('update_payment_allocation_amount', {
    p_tenant_id: payload.tenant_id,
    p_allocation_id: payload.allocation_id,
    p_amount: payload.amount,
  })
  if (error) throw error
  if (!data) throw new Error('Payment allocation was not updated.')
  return data as PaymentAllocation
}

const updatePayment = async (payload: UpdatePaymentInput): Promise<Payment> => {
  const { data, error } = await supabase
    .from('payments')
    .update(payload.patch)
    .eq('tenant_id', payload.tenant_id)
    .eq('id', payload.payment_id)
    .select('*')
    .single()
  if (error) throw error
  if (!data) throw new Error('Payment was not updated.')
  return data as Payment
}

const deletePayment = async (payload: DeletePaymentInput): Promise<void> => {
  const { data: allocations, error: allocationReadError } = await supabase
    .from('payment_allocations')
    .select('invoice_id')
    .eq('tenant_id', payload.tenant_id)
    .eq('payment_id', payload.payment_id)
  if (allocationReadError) throw allocationReadError

  const invoiceIds = Array.from(new Set((allocations ?? []).map((row) => Number(row.invoice_id)).filter(Number.isFinite)))

  const { error: allocationDeleteError } = await supabase
    .from('payment_allocations')
    .delete()
    .eq('tenant_id', payload.tenant_id)
    .eq('payment_id', payload.payment_id)
  if (allocationDeleteError) throw allocationDeleteError

  const { error } = await supabase
    .from('payments')
    .delete()
    .eq('tenant_id', payload.tenant_id)
    .eq('id', payload.payment_id)
  if (error) throw error

  for (const invoiceId of invoiceIds) {
    await recomputeInvoicePaymentStatus(invoiceId)
  }
}

export const invoiceRepository = {
  listInvoices,
  listInvoiceItems,
  listPayments,
  listPaymentAllocations,
  createPaymentWithAllocations,
  addPaymentAllocation,
  updatePaymentAllocationAmount,
  updatePayment,
  deletePayment,
  createInvoice,
  updateInvoice,
  deleteInvoice,
  createInvoiceItem,
  updateInvoiceItem,
  deleteInvoiceItem,
  recomputeInvoicePaymentStatus,
  applyInvoiceItemReturn,
}
