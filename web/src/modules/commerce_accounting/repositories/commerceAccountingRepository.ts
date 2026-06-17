import { supabase } from 'src/boot/supabase'
import type { Database } from 'src/types/supabase'
import type { CommerceAccounting, CommerceAccountingDetails } from '../types'

type AccountingEntryRow = Database['public']['Tables']['inventory_accounting_entries']['Row']

const mapRow = (row: AccountingEntryRow): CommerceAccounting => ({
  id: row.id,
  tenant_id: row.tenant_id,
  order_item_id: row.commerce_order_item_id,
  cost_bdt: Number(row.cost_amount || 0),
  shipment_item_id: row.shipment_item_id,
  sell_price_bdt: Number(row.sell_price_amount || 0),
  recipient_sell_price_bdt: Number(row.recipient_sell_price_amount || 0),
  customer_group_id: row.customer_group_id,
  billing_profile_id: row.billing_profile_id,
  is_customer_group_paid: row.status === 'paid',
  created_at: row.created_at,
  updated_at: row.updated_at || row.created_at,
})

const listCommerceAccounting = async (tenantId: number): Promise<CommerceAccountingDetails[]> => {
  const { data, error } = await supabase
    .from('inventory_accounting_entries')
    .select('*')
    .eq('type', 'commerce')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: false })

  if (error) throw error

  const rows = (data || []).map(mapRow)
  const orderItemIds = Array.from(
    new Set(rows.map((row) => row.order_item_id).filter((id): id is number => Boolean(id))),
  )

  const orderPaymentStatusByOrderItemId = new Map<number, boolean | null>()

  if (orderItemIds.length > 0) {
    const { data: orderItems, error: orderItemsError } = await supabase
      .from('commerce_order_items')
      .select('id, invoice_id')
      .in('id', orderItemIds)

    if (orderItemsError) throw orderItemsError

    const invoiceIds = Array.from(
      new Set((orderItems || []).map((item) => item.invoice_id).filter((id): id is number => Boolean(id))),
    )

    const invoicePaymentStatusById = new Map<number, boolean>()
    if (invoiceIds.length > 0) {
      const { data: invoices, error: invoicesError } = await supabase
        .from('commerce_invoices')
        .select('id, is_customer_group_paid')
        .in('id', invoiceIds)

      if (invoicesError) throw invoicesError

      for (const invoice of invoices || []) {
        invoicePaymentStatusById.set(invoice.id, invoice.is_customer_group_paid)
      }
    }

    for (const orderItem of orderItems || []) {
      if (orderItem.invoice_id) {
        orderPaymentStatusByOrderItemId.set(
          orderItem.id,
          invoicePaymentStatusById.get(orderItem.invoice_id) ?? null,
        )
      }
    }
  }

  return rows.map((row) => ({
    ...row,
    order_payment_status: row.order_item_id ? (orderPaymentStatusByOrderItemId.get(row.order_item_id) ?? null) : null,
  }))
}

const updateAccountingPaymentStatus = async (
  entryId: number,
  isPaid: boolean,
): Promise<CommerceAccounting> => {
  const { data, error } = await supabase
    .from('inventory_accounting_entries')
    .update({ status: isPaid ? 'paid' : 'due' })
    .eq('id', entryId)
    .select('*')
    .single()

  if (error) throw error
  return mapRow(data)
}

export const commerceAccountingRepository = {
  listCommerceAccounting,
  updateAccountingPaymentStatus,
}
