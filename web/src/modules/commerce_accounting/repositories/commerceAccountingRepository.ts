import { supabase } from 'src/boot/supabase'
import type { CommerceAccounting, CommerceAccountingDetails } from '../types'

const listCommerceAccounting = async (tenantId: number): Promise<CommerceAccountingDetails[]> => {
  const { data, error } = await supabase
    .from('commerce_accounting')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: false })

  if (error) throw error

  const rows = (data || []) as CommerceAccounting[]
  const orderItemIds = Array.from(new Set(rows.map((row) => row.order_item_id).filter((id) => Boolean(id))))

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
    order_payment_status: orderPaymentStatusByOrderItemId.get(row.order_item_id) ?? null,
  }))
}

const updateAccountingPaymentStatus = async (
  entryId: number,
  isPaid: boolean,
): Promise<CommerceAccounting> => {
  const { data, error } = await supabase
    .from('commerce_accounting')
    .update({ is_customer_group_paid: isPaid })
    .eq('id', entryId)
    .select('*')
    .single()

  if (error) throw error
  return data
}

export const commerceAccountingRepository = {
  listCommerceAccounting,
  updateAccountingPaymentStatus,
}
