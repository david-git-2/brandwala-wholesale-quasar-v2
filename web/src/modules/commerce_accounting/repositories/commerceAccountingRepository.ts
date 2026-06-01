import { supabase } from 'src/boot/supabase'
import type { CommerceAccounting } from '../types'

const listCommerceAccounting = async (tenantId: number): Promise<CommerceAccounting[]> => {
  const { data, error } = await supabase
    .from('commerce_accounting')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: false })

  if (error) throw error
  return data || []
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
