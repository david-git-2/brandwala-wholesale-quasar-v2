import { supabase } from 'src/boot/supabase'
import type {
  CreateGlobalInvoiceInput,
  GlobalInvoiceCreated,
  GlobalInvoiceDetail,
  GlobalInvoiceItemRow,
  GlobalInvoiceRow,
} from '../types'

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
    p_invoice_date: payload.invoice_date ?? null,
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
    .select(`
      id,
      invoice_id,
      global_stock_id,
      name_snapshot,
      quantity,
      sell_price_amount,
      recipient_price_amount,
      line_face_total_amount,
      line_discount_amount,
      line_total_amount,
      unit_cost_price,
      return_quantity,
      global_stocks (
        global_shipment_items (
          image_url
        )
      ),
      products (
        image_url
      )
    `)
    .eq('invoice_id', invoiceId)
    .order('id', { ascending: true })

  if (error) throw error

  return ((data as any[]) ?? []).map((row) => {
    const globalStocks = Array.isArray(row.global_stocks) ? row.global_stocks[0] : row.global_stocks
    const globalShipmentItems = globalStocks ? (Array.isArray(globalStocks.global_shipment_items) ? globalStocks.global_shipment_items[0] : globalStocks.global_shipment_items) : null
    const products = Array.isArray(row.products) ? row.products[0] : row.products
    const imageUrl = globalShipmentItems?.image_url || products?.image_url || null

    return {
      id: row.id,
      invoice_id: row.invoice_id,
      global_stock_id: row.global_stock_id,
      name_snapshot: row.name_snapshot,
      quantity: row.quantity,
      sell_price_amount: row.sell_price_amount,
      recipient_price_amount: row.recipient_price_amount,
      line_face_total_amount: row.line_face_total_amount,
      line_discount_amount: row.line_discount_amount,
      line_total_amount: row.line_total_amount,
      unit_cost_price: row.unit_cost_price,
      return_quantity: row.return_quantity,
      image_url: imageUrl,
    }
  })
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

const applySettlementDiscount = async (invoiceId: number, amount: number, note?: string | null) => {
  const { data, error } = await supabase.rpc('apply_global_invoice_settlement_discount', {
    p_invoice_id: invoiceId,
    p_amount: amount,
    p_note: note ?? null,
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

const removeGlobalInvoiceItem = async (invoiceItemId: number): Promise<void> => {
  const { error } = await supabase.rpc('remove_global_invoice_item', {
    p_invoice_item_id: invoiceItemId,
  })
  if (error) throw error
}

const updateGlobalInvoiceItem = async (payload: {
  id: number
  quantity: number
  sell_price_amount: number
  recipient_price_amount?: number
}): Promise<GlobalInvoiceItemRow> => {
  const { data, error } = await supabase.rpc('update_global_invoice_item', {
    p_item_id: payload.id,
    p_quantity: payload.quantity,
    p_sell_price_amount: payload.sell_price_amount,
    p_recipient_price_amount: payload.recipient_price_amount ?? null,
  })

  if (error) throw error
  return data as GlobalInvoiceItemRow
}

export type TargetTotalLineChange = {
  item_id: number
  name: string
  quantity: number
  old_price: number
  new_price: number
  unit_delta: number
  line_delta: number
}

export type TargetTotalSummary = {
  current_total: number
  target_total: number
  adjustment: number
  is_dropship: boolean
  lines: TargetTotalLineChange[]
}

const applyGlobalInvoiceTargetTotal = async (payload: {
  id: number
  target_total: number
  dry_run?: boolean
}): Promise<TargetTotalSummary> => {
  const { data, error } = await supabase.rpc('apply_global_invoice_target_total', {
    p_invoice_id: payload.id,
    p_target_total: payload.target_total,
    p_dry_run: payload.dry_run ?? false,
  })

  if (error) throw error
  return data as unknown as TargetTotalSummary
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
  invoice_no?: string | null
  invoice_date?: string | null
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
    p_invoice_no: payload.invoice_no ?? null,
    p_invoice_date: payload.invoice_date ?? null,
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

const unpostGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('unpost_global_invoice', {
    p_invoice_id: invoiceId,
  })
  if (error) throw error
}

const deleteGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.from('global_invoices').delete().eq('id', invoiceId)
  if (error) throw error
}


export type InvoiceBrand = {
  id: number
  tenant_id: number
  name: string
  address: string
  created_at?: string
  updated_at?: string
}

export type CreateInvoiceBrandInput = Omit<InvoiceBrand, 'id' | 'created_at' | 'updated_at'>

const listInvoiceBrands = async (payload: { tenant_id?: number } = {}): Promise<(InvoiceBrand & { tenants?: { name: string } })[]> => {
  let query = supabase.from('invoice_brands').select('*, tenants(name)')
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }
  const { data, error } = await query.order('name', { ascending: true })
  if (error) throw error
  return (data) || []
}

const createInvoiceBrand = async (payload: CreateInvoiceBrandInput): Promise<InvoiceBrand> => {
  const { data, error } = await supabase.from('invoice_brands').insert([payload]).select('*').single()
  if (error) throw error
  return data as InvoiceBrand
}

const updateInvoiceBrand = async (payload: { id: number; patch: Partial<Omit<InvoiceBrand, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }): Promise<InvoiceBrand> => {
  const { data, error } = await supabase
    .from('invoice_brands')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()
  if (error) throw error
  return data as InvoiceBrand
}

const deleteInvoiceBrand = async (payload: { id: number }): Promise<void> => {
  const { error } = await supabase.from('invoice_brands').delete().eq('id', payload.id)
  if (error) throw error
}

export const invoiceRepository = {
  listGlobalInvoices,
  createGlobalInvoice,
  getGlobalInvoiceById,
  listGlobalInvoiceItems,
  addGlobalInvoiceItem,
  updateGlobalInvoiceItem,
  applyGlobalInvoiceTargetTotal,
  recordBillingProfilePayment,
  recordRecipientInvoiceCollection,
  applySettlementDiscount,
  createMiddleManPayout,
  addGlobalReturnItem,
  getGlobalInvoicesPaidAmounts,
  removeGlobalInvoiceItem,
  updateGlobalInvoiceHeader,
  postGlobalInvoice,
  voidGlobalInvoice,
  unpostGlobalInvoice,
  deleteGlobalInvoice,
  listInvoiceBrands,
  createInvoiceBrand,
  updateInvoiceBrand,
  deleteInvoiceBrand,
}

