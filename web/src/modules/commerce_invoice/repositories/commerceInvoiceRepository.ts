import { supabase } from 'src/boot/supabase'
import type { CommerceInvoice } from '../types'

const listCommerceInvoices = async (tenantId: number): Promise<CommerceInvoice[]> => {
  const { data, error } = await supabase
    .from('commerce_invoices')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: false })

  if (error) throw error
  return data || []
}

const updateInvoicePayment = async (
  invoiceId: number,
  amountPaid: number,
): Promise<CommerceInvoice> => {
  const { data: invoice, error: getError } = await supabase
    .from('commerce_invoices')
    .select('*')
    .eq('id', invoiceId)
    .single()

  if (getError) throw getError

  const newAmountPaid = Number(invoice.amount_paid) + amountPaid
  const newAmountDue = Math.max(0, Number(invoice.total_amount) - newAmountPaid)
  const isPaid = newAmountPaid >= Number(invoice.total_amount)

  const { data, error } = await supabase
    .from('commerce_invoices')
    .update({
      amount_paid: newAmountPaid,
      amount_due: newAmountDue,
      is_customer_group_paid: isPaid,
    })
    .eq('id', invoiceId)
    .select('*')
    .single()

  if (error) throw error
  return data
}

export const commerceInvoiceRepository = {
  listCommerceInvoices,
  updateInvoicePayment,
}
